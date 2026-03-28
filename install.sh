#!/bin/bash
# ============================================================================
# Chill Dots installer
# Restores your full Hyprland/Omarchy rice on a fresh Arch + Omarchy install
#
# Usage: Clone this repo, install Omarchy first, then run:
#   chmod +x install.sh && ./install.sh
#
# Safe to re-run: each step checks actual state before acting.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

# Issue tracker — collects all warnings/errors for summary
ISSUES=()

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ISSUES+=("WARN: $1"); }
err()   { echo -e "${RED}[ERROR]${NC} $1"; ISSUES+=("ERROR: $1"); }
skip()  { echo -e "${GRAY}[SKIP]${NC} $1"; }

# ============================================================================
# Pre-flight checks
# ============================================================================

if [[ ! -d "$HOME/.local/share/omarchy" ]]; then
    err "Omarchy not found. Install Omarchy first, then re-run this script."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    err "This script is for Arch Linux only."
    exit 1
fi

echo ""
echo "============================================"
echo "  Chill Dots installer"
echo "  Restoring your Hyprland/Omarchy rice"
echo "============================================"
echo ""

# ============================================================================
# Step 1: Install packages
# ============================================================================

info "Step 1/7: Checking packages..."

# Install yay if not present (needed for AUR packages)
if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    if sudo pacman -S --needed --noconfirm git base-devel; then
        tmpdir=$(mktemp -d)
        if git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" && \
           (cd "$tmpdir/yay" && makepkg -si --noconfirm); then
            ok "yay installed"
        else
            err "Failed to build yay from AUR"
        fi
        rm -rf "$tmpdir"
    else
        err "Failed to install yay dependencies"
    fi
else
    skip "yay already installed"
fi

# Install official packages one by one so a single bad package doesn't block the rest
pkg_installed=0
pkg_failed=0
pkg_skipped=0
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if pacman -Qi "$pkg" &>/dev/null; then
        pkg_skipped=$((pkg_skipped + 1))
    else
        if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
            pkg_installed=$((pkg_installed + 1))
        else
            warn "Failed to install official package: $pkg"
            pkg_failed=$((pkg_failed + 1))
        fi
    fi
done < "$SCRIPT_DIR/pkglist-official.txt"

if [[ $pkg_installed -gt 0 || $pkg_failed -gt 0 ]]; then
    ok "Official packages: $pkg_installed installed, $pkg_skipped already present, $pkg_failed failed"
else
    skip "All official packages already installed"
fi

# Install AUR packages one by one
aur_installed=0
aur_failed=0
aur_skipped=0
if command -v yay &>/dev/null; then
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        if pacman -Qi "$pkg" &>/dev/null; then
            aur_skipped=$((aur_skipped + 1))
        else
            if yay -S --needed --noconfirm "$pkg" &>/dev/null; then
                aur_installed=$((aur_installed + 1))
            else
                warn "Failed to install AUR package: $pkg"
                aur_failed=$((aur_failed + 1))
            fi
        fi
    done < "$SCRIPT_DIR/pkglist-aur.txt"

    if [[ $aur_installed -gt 0 || $aur_failed -gt 0 ]]; then
        ok "AUR packages: $aur_installed installed, $aur_skipped already present, $aur_failed failed"
    else
        skip "All AUR packages already installed"
    fi
else
    err "yay not available — skipping all AUR packages"
fi

# ============================================================================
# Step 2: Backup existing configs (only if no backup exists yet)
# ============================================================================

info "Step 2/7: Checking backup..."

existing_backup=$(find "$HOME" -maxdepth 1 -name ".config-backup-*" -type d 2>/dev/null | head -1)
if [[ -n "$existing_backup" ]]; then
    skip "Backup already exists at $existing_backup"
else
    BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    info "Backing up existing configs to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"

    for dir in hypr waybar kitty ghostty mako walker swayosd waypaper wallust fastfetch btop tmux nvim; do
        if [[ -d "$HOME/.config/$dir" ]]; then
            cp -r "$HOME/.config/$dir" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    [[ -f "$HOME/.config/starship.toml" ]] && cp "$HOME/.config/starship.toml" "$BACKUP_DIR/" || true
    [[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$BACKUP_DIR/" || true

    ok "Backup saved to $BACKUP_DIR"
fi

# ============================================================================
# Step 3: Copy wallpapers
# ============================================================================

info "Step 3/7: Copying wallpapers..."
mkdir -p "$HOME/Pictures/Wallpapers"

copied=0
skipped=0
failed=0
while IFS= read -r -d '' src; do
    filename="$(basename "$src")"
    dest="$HOME/Pictures/Wallpapers/$filename"
    if [[ -f "$dest" ]]; then
        skipped=$((skipped + 1))
    else
        if cp -- "$src" "$dest"; then
            copied=$((copied + 1))
        else
            warn "Failed to copy wallpaper: $filename"
            failed=$((failed + 1))
        fi
    fi
done < <(find "$SCRIPT_DIR/wallpapers" -maxdepth 1 -type f -print0 2>/dev/null)

if [[ $copied -eq 0 && $failed -eq 0 ]]; then
    skip "All $skipped wallpapers already in ~/Pictures/Wallpapers/"
else
    ok "Wallpapers: $copied copied, $skipped already existed, $failed failed"
fi

# ============================================================================
# Step 4: Deploy config files
# ============================================================================

info "Step 4/7: Deploying config files..."

# Helper: copy file only if source and dest differ
deploy() {
    local src="$1" dest="$2"
    if [[ ! -f "$src" ]]; then
        warn "Source file missing: $src"
        return 1
    fi
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        return 1  # no change needed
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    return 0
}

changes=0

# Hyprland
mkdir -p "$HOME/.config/hypr/scripts" "$HOME/.config/hypr/wallust"
for f in hyprland.conf looknfeel.conf bindings.conf monitors.conf input.conf autostart.conf hypridle.conf hyprlock.conf hyprsunset.conf xdph.conf; do
    if deploy "$SCRIPT_DIR/configs/hypr/$f" "$HOME/.config/hypr/$f"; then
        changes=$((changes + 1))
    fi
done
if deploy "$SCRIPT_DIR/configs/hypr/scripts/wallpaper.sh" "$HOME/.config/hypr/scripts/wallpaper.sh"; then
    changes=$((changes + 1))
fi
chmod +x "$HOME/.config/hypr/scripts/wallpaper.sh" 2>/dev/null || true

# Wallust (auto-theming)
mkdir -p "$HOME/.config/wallust/templates"
if deploy "$SCRIPT_DIR/configs/wallust/wallust.toml" "$HOME/.config/wallust/wallust.toml"; then
    changes=$((changes + 1))
fi
for src in "$SCRIPT_DIR/configs/wallust/templates/"*; do
    [[ -f "$src" ]] || continue
    if deploy "$src" "$HOME/.config/wallust/templates/$(basename "$src")"; then
        changes=$((changes + 1))
    fi
done

# Waybar
mkdir -p "$HOME/.config/waybar/scripts" "$HOME/.config/waybar/wallust"
for f in config.jsonc style.css mocha.css; do
    if deploy "$SCRIPT_DIR/configs/waybar/$f" "$HOME/.config/waybar/$f"; then
        changes=$((changes + 1))
    fi
done
if deploy "$SCRIPT_DIR/configs/waybar/scripts/waybar-wttr.py" "$HOME/.config/waybar/scripts/waybar-wttr.py"; then
    changes=$((changes + 1))
fi
chmod +x "$HOME/.config/waybar/scripts/waybar-wttr.py" 2>/dev/null || true

# Kitty
mkdir -p "$HOME/.config/kitty"
if deploy "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"; then
    changes=$((changes + 1))
fi

# Ghostty (if config exists)
if [[ -f "$SCRIPT_DIR/configs/ghostty/config" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    if deploy "$SCRIPT_DIR/configs/ghostty/config" "$HOME/.config/ghostty/config"; then
        changes=$((changes + 1))
    fi
fi

# Mako
mkdir -p "$HOME/.config/mako"
if deploy "$SCRIPT_DIR/configs/mako/config" "$HOME/.config/mako/config"; then
    changes=$((changes + 1))
fi

# Starship
if deploy "$SCRIPT_DIR/configs/starship/starship.toml" "$HOME/.config/starship.toml"; then
    changes=$((changes + 1))
fi

# Walker
mkdir -p "$HOME/.config/walker/themes"
if deploy "$SCRIPT_DIR/configs/walker/config.toml" "$HOME/.config/walker/config.toml"; then
    changes=$((changes + 1))
fi

# SwayOSD
mkdir -p "$HOME/.config/swayosd"
for f in config.toml style.css; do
    if deploy "$SCRIPT_DIR/configs/swayosd/$f" "$HOME/.config/swayosd/$f"; then
        changes=$((changes + 1))
    fi
done

# Waypaper
mkdir -p "$HOME/.config/waypaper"
if deploy "$SCRIPT_DIR/configs/waypaper/config.ini" "$HOME/.config/waypaper/config.ini"; then
    sed -i "s|/home/lurayy|$HOME|g" "$HOME/.config/waypaper/config.ini"
    changes=$((changes + 1))
else
    # Still fix paths even if file was already there
    if grep -q "/home/lurayy" "$HOME/.config/waypaper/config.ini" 2>/dev/null; then
        sed -i "s|/home/lurayy|$HOME|g" "$HOME/.config/waypaper/config.ini"
        changes=$((changes + 1))
    fi
fi

# Omarchy hooks & extensions
mkdir -p "$HOME/.config/omarchy/hooks" "$HOME/.config/omarchy/extensions"
if deploy "$SCRIPT_DIR/configs/omarchy/hooks/theme-set" "$HOME/.config/omarchy/hooks/theme-set"; then
    changes=$((changes + 1))
fi
if deploy "$SCRIPT_DIR/configs/omarchy/extensions/menu.sh" "$HOME/.config/omarchy/extensions/menu.sh"; then
    changes=$((changes + 1))
fi
chmod +x "$HOME/.config/omarchy/hooks/theme-set" 2>/dev/null || true

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"
for f in config.jsonc logo.txt; do
    if deploy "$SCRIPT_DIR/configs/fastfetch/$f" "$HOME/.config/fastfetch/$f"; then
        changes=$((changes + 1))
    fi
done

# Btop
mkdir -p "$HOME/.config/btop"
if deploy "$SCRIPT_DIR/configs/btop/btop.conf" "$HOME/.config/btop/btop.conf"; then
    changes=$((changes + 1))
fi

# Tmux
mkdir -p "$HOME/.config/tmux"
if deploy "$SCRIPT_DIR/configs/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"; then
    changes=$((changes + 1))
fi

# Neovim (LazyVim)
mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins" "$HOME/.config/nvim/plugin/after"
for f in init.lua lazy-lock.json lazyvim.json stylua.toml; do
    if deploy "$SCRIPT_DIR/configs/nvim/$f" "$HOME/.config/nvim/$f"; then
        changes=$((changes + 1))
    fi
done
for dir in lua/config lua/plugins plugin/after; do
    for src in "$SCRIPT_DIR/configs/nvim/$dir/"*; do
        [[ -f "$src" ]] || continue
        if deploy "$src" "$HOME/.config/nvim/$dir/$(basename "$src")"; then
            changes=$((changes + 1))
        fi
    done
done

if [[ $changes -eq 0 ]]; then
    skip "All config files already up to date"
else
    ok "$changes config files deployed/updated"
fi

# ============================================================================
# Step 5: Shell setup (zsh + oh-my-zsh + plugins + starship)
# ============================================================================

info "Step 5/7: Setting up shell..."

# Install oh-my-zsh if not present
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        ok "Oh My Zsh installed"
    else
        err "Failed to install Oh My Zsh"
    fi
else
    skip "Oh My Zsh already installed"
fi

# Install zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A zsh_plugins=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["autoswitch_virtualenv"]="https://github.com/MichaelAqworthy/zsh-autoswitch-virtualenv"
)

for plugin in "${!zsh_plugins[@]}"; do
    if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]]; then
        if git clone "${zsh_plugins[$plugin]}" "$ZSH_CUSTOM/plugins/$plugin" &>/dev/null; then
            ok "$plugin installed"
        else
            err "Failed to clone $plugin"
        fi
    else
        skip "$plugin already installed"
    fi
done

# Deploy .zshrc only if different
if [[ -f "$HOME/.zshrc" ]] && cmp -s "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"; then
    skip ".zshrc already up to date"
else
    if cp "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"; then
        ok ".zshrc deployed"
    else
        err "Failed to deploy .zshrc"
    fi
fi

# Set zsh as default shell if not already
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Setting zsh as default shell..."
    if chsh -s "$(which zsh)"; then
        ok "Default shell set to zsh"
    else
        warn "Failed to set zsh as default shell — run manually: chsh -s \$(which zsh)"
    fi
else
    skip "zsh already default shell"
fi

# ============================================================================
# Step 6: Systemd user services
# ============================================================================

info "Step 6/7: Setting up systemd services..."

mkdir -p "$HOME/.config/systemd/user"

svc_changes=0
for f in wallpaper-rotate.timer wallpaper-rotate.service elephant.service; do
    if [[ ! -f "$SCRIPT_DIR/systemd/$f" ]]; then
        warn "Systemd unit file missing from repo: $f"
        continue
    fi
    if [[ -f "$HOME/.config/systemd/user/$f" ]] && cmp -s "$SCRIPT_DIR/systemd/$f" "$HOME/.config/systemd/user/$f"; then
        continue
    fi
    cp "$SCRIPT_DIR/systemd/$f" "$HOME/.config/systemd/user/"
    svc_changes=$((svc_changes + 1))
done

# Walker auto-restart drop-in
mkdir -p "$HOME/.config/systemd/user/app-walker@autostart.service.d"
if [[ -f "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" ]]; then
    if ! cmp -s "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" "$HOME/.config/systemd/user/app-walker@autostart.service.d/restart.conf" 2>/dev/null; then
        cp "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" "$HOME/.config/systemd/user/app-walker@autostart.service.d/"
        svc_changes=$((svc_changes + 1))
    fi
fi

if [[ $svc_changes -gt 0 ]]; then
    if systemctl --user daemon-reload 2>/dev/null; then
        ok "$svc_changes systemd unit files updated"
    else
        warn "Failed to reload systemd daemon — may need active session"
    fi
else
    skip "Systemd unit files already up to date"
fi

# Enable wallpaper rotation timer if not already active
if systemctl --user is-enabled wallpaper-rotate.timer &>/dev/null; then
    skip "wallpaper-rotate.timer already enabled"
else
    if systemctl --user enable --now wallpaper-rotate.timer 2>/dev/null; then
        ok "Wallpaper rotation enabled (every 20 minutes)"
    else
        warn "Could not enable wallpaper-rotate.timer — enable manually after login"
    fi
fi

# Enable elephant audio service if not already enabled
if systemctl --user is-enabled elephant.service &>/dev/null; then
    skip "elephant.service already enabled"
else
    if systemctl --user enable elephant.service 2>/dev/null; then
        ok "Elephant audio service enabled"
    else
        warn "Could not enable elephant.service — enable manually after login"
    fi
fi

# Disable the systemd waybar service to prevent duplicate waybar instances
if systemctl --user is-enabled waybar.service &>/dev/null 2>&1; then
    systemctl --user disable waybar.service 2>/dev/null || true
    ok "Disabled duplicate waybar.service"
else
    skip "waybar.service already disabled"
fi

# ============================================================================
# Step 7: Apply theme and generate wallust colors
# ============================================================================

info "Step 7/7: Applying theme and wallust colors..."

# Set the omarchy theme
THEME_NAME="klein-cosmic"
if [[ -f "$SCRIPT_DIR/configs/omarchy/theme.name" ]]; then
    THEME_NAME="$(cat "$SCRIPT_DIR/configs/omarchy/theme.name")"
fi

if command -v omarchy-theme-set &>/dev/null; then
    omarchy-theme-set "$THEME_NAME" 2>/dev/null || warn "Could not set theme (may need active Hyprland session)"
else
    warn "omarchy-theme-set not found, set theme manually after login"
fi

# Set the default wallpaper symlink
DEFAULT_WALLPAPER="$HOME/Pictures/Wallpapers/Lofi_Cat.png"
if [[ -f "$DEFAULT_WALLPAPER" ]]; then
    mkdir -p "$HOME/.config/omarchy/current"
    current_target=$(readlink -f "$HOME/.config/omarchy/current/background" 2>/dev/null || echo "")
    if [[ "$current_target" == "$DEFAULT_WALLPAPER" ]]; then
        skip "Default wallpaper symlink already set"
    else
        ln -sf "$DEFAULT_WALLPAPER" "$HOME/.config/omarchy/current/background"
        ok "Default wallpaper set to Lofi_Cat.png"
    fi
else
    warn "Default wallpaper not found at $DEFAULT_WALLPAPER — wallpaper copy may have failed"
fi

# Generate wallust colors from the wallpaper
if command -v wallust &>/dev/null && [[ -f "$DEFAULT_WALLPAPER" ]]; then
    if [[ -f "$HOME/.cache/wallust/nix.json" ]]; then
        skip "Wallust colors already generated"
    else
        info "Generating wallust color scheme from wallpaper..."
        mkdir -p "$HOME/.cache/wallust"
        if wallust run "$DEFAULT_WALLPAPER" 2>/dev/null; then
            ok "Wallust colors generated"
        else
            warn "wallust color generation failed (may need display)"
        fi
    fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}Installation complete!${NC}"
else
    echo -e "  ${YELLOW}Installation complete with ${#ISSUES[@]} issue(s)${NC}"
fi

echo "============================================"
echo ""
echo "  What was set up:"
echo "    - All packages (official + AUR)"
echo "    - Hyprland + custom animations, blur, borders"
echo "    - Waybar (Catppuccin Mocha theme + weather)"
echo "    - Wallust auto-theming (colors from wallpaper)"
echo "    - Kitty + Ghostty terminal configs"
echo "    - Neovim (LazyVim + custom plugins)"
echo "    - Tmux with custom keybindings"
echo "    - Fastfetch with custom logo"
echo "    - Btop system monitor"
echo "    - Wallpaper rotation (every 20 min)"
echo "    - Starship prompt + Oh My Zsh"
echo "    - CopyQ clipboard manager"
echo "    - SwayOSD + Mako notifications"
echo "    - Walker launcher with auto-restart"

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}Issues encountered:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "    ${YELLOW}-${NC} $issue"
    done
fi

echo ""
echo "  Next steps:"
echo "    1. Log out and back in (or reboot)"
echo "    2. If monitors look wrong, edit:"
echo "       ~/.config/hypr/monitors.conf"
echo ""
