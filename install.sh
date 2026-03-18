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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }
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
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    ok "yay installed"
else
    skip "yay already installed"
fi

# Check if all official packages are installed
missing_official=()
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if ! pacman -Qi "$pkg" &>/dev/null; then
        missing_official+=("$pkg")
    fi
done < "$SCRIPT_DIR/pkglist-official.txt"

if [[ ${#missing_official[@]} -gt 0 ]]; then
    info "Installing ${#missing_official[@]} missing official packages..."
    sudo pacman -S --needed --noconfirm "${missing_official[@]}" || warn "Some official packages failed to install"
    ok "Official packages installed"
else
    skip "All official packages already installed"
fi

# Check if all AUR packages are installed
missing_aur=()
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if ! pacman -Qi "$pkg" &>/dev/null; then
        missing_aur+=("$pkg")
    fi
done < "$SCRIPT_DIR/pkglist-aur.txt"

if [[ ${#missing_aur[@]} -gt 0 ]]; then
    info "Installing ${#missing_aur[@]} missing AUR packages..."
    yay -S --needed --noconfirm "${missing_aur[@]}" || warn "Some AUR packages failed to install"
    ok "AUR packages installed"
else
    skip "All AUR packages already installed"
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
        ((skipped++))
    else
        if cp -- "$src" "$dest"; then
            ((copied++))
        else
            warn "Failed to copy: $filename"
            ((failed++))
        fi
    fi
done < <(find "$SCRIPT_DIR/wallpapers" -maxdepth 1 -type f -print0)

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
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        return 1  # no change needed
    fi
    cp "$src" "$dest"
    return 0
}

changes=0

# Hyprland
mkdir -p "$HOME/.config/hypr/scripts" "$HOME/.config/hypr/wallust"
for f in hyprland.conf looknfeel.conf bindings.conf monitors.conf input.conf autostart.conf hypridle.conf hyprlock.conf hyprsunset.conf xdph.conf; do
    deploy "$SCRIPT_DIR/configs/hypr/$f" "$HOME/.config/hypr/$f" && ((changes++)) || true
done
deploy "$SCRIPT_DIR/configs/hypr/scripts/wallpaper.sh" "$HOME/.config/hypr/scripts/wallpaper.sh" && ((changes++)) || true
chmod +x "$HOME/.config/hypr/scripts/wallpaper.sh"

# Wallust (auto-theming)
mkdir -p "$HOME/.config/wallust/templates"
deploy "$SCRIPT_DIR/configs/wallust/wallust.toml" "$HOME/.config/wallust/wallust.toml" && ((changes++)) || true
for src in "$SCRIPT_DIR/configs/wallust/templates/"*; do
    [[ -f "$src" ]] || continue
    deploy "$src" "$HOME/.config/wallust/templates/$(basename "$src")" && ((changes++)) || true
done

# Waybar
mkdir -p "$HOME/.config/waybar/scripts" "$HOME/.config/waybar/wallust"
deploy "$SCRIPT_DIR/configs/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc" && ((changes++)) || true
deploy "$SCRIPT_DIR/configs/waybar/style.css" "$HOME/.config/waybar/style.css" && ((changes++)) || true
deploy "$SCRIPT_DIR/configs/waybar/mocha.css" "$HOME/.config/waybar/mocha.css" && ((changes++)) || true
deploy "$SCRIPT_DIR/configs/waybar/scripts/waybar-wttr.py" "$HOME/.config/waybar/scripts/waybar-wttr.py" && ((changes++)) || true
chmod +x "$HOME/.config/waybar/scripts/waybar-wttr.py"

# Kitty
mkdir -p "$HOME/.config/kitty"
deploy "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" && ((changes++)) || true

# Ghostty (if config exists)
if [[ -f "$SCRIPT_DIR/configs/ghostty/config" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    deploy "$SCRIPT_DIR/configs/ghostty/config" "$HOME/.config/ghostty/config" && ((changes++)) || true
fi

# Mako
mkdir -p "$HOME/.config/mako"
deploy "$SCRIPT_DIR/configs/mako/config" "$HOME/.config/mako/config" && ((changes++)) || true

# Starship
deploy "$SCRIPT_DIR/configs/starship/starship.toml" "$HOME/.config/starship.toml" && ((changes++)) || true

# Walker
mkdir -p "$HOME/.config/walker/themes"
deploy "$SCRIPT_DIR/configs/walker/config.toml" "$HOME/.config/walker/config.toml" && ((changes++)) || true

# SwayOSD
mkdir -p "$HOME/.config/swayosd"
deploy "$SCRIPT_DIR/configs/swayosd/config.toml" "$HOME/.config/swayosd/config.toml" && ((changes++)) || true
deploy "$SCRIPT_DIR/configs/swayosd/style.css" "$HOME/.config/swayosd/style.css" && ((changes++)) || true

# Waypaper
mkdir -p "$HOME/.config/waypaper"
if deploy "$SCRIPT_DIR/configs/waypaper/config.ini" "$HOME/.config/waypaper/config.ini"; then
    sed -i "s|/home/lurayy|$HOME|g" "$HOME/.config/waypaper/config.ini"
    ((changes++))
else
    # Still fix paths even if file was already there
    if grep -q "/home/lurayy" "$HOME/.config/waypaper/config.ini" 2>/dev/null; then
        sed -i "s|/home/lurayy|$HOME|g" "$HOME/.config/waypaper/config.ini"
        ((changes++))
    fi
fi

# Omarchy hooks & extensions
mkdir -p "$HOME/.config/omarchy/hooks" "$HOME/.config/omarchy/extensions"
deploy "$SCRIPT_DIR/configs/omarchy/hooks/theme-set" "$HOME/.config/omarchy/hooks/theme-set" && ((changes++)) || true
deploy "$SCRIPT_DIR/configs/omarchy/extensions/menu.sh" "$HOME/.config/omarchy/extensions/menu.sh" && ((changes++)) || true
chmod +x "$HOME/.config/omarchy/hooks/theme-set"

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"
deploy "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc" && ((changes++)) || true
deploy "$SCRIPT_DIR/configs/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt" && ((changes++)) || true

# Btop
mkdir -p "$HOME/.config/btop"
deploy "$SCRIPT_DIR/configs/btop/btop.conf" "$HOME/.config/btop/btop.conf" && ((changes++)) || true

# Tmux
mkdir -p "$HOME/.config/tmux"
deploy "$SCRIPT_DIR/configs/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf" && ((changes++)) || true

# Neovim (LazyVim)
mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins" "$HOME/.config/nvim/plugin/after"
for f in init.lua lazy-lock.json lazyvim.json stylua.toml; do
    deploy "$SCRIPT_DIR/configs/nvim/$f" "$HOME/.config/nvim/$f" && ((changes++)) || true
done
for src in "$SCRIPT_DIR/configs/nvim/lua/config/"*; do
    [[ -f "$src" ]] || continue
    deploy "$src" "$HOME/.config/nvim/lua/config/$(basename "$src")" && ((changes++)) || true
done
for src in "$SCRIPT_DIR/configs/nvim/lua/plugins/"*; do
    [[ -f "$src" ]] || continue
    deploy "$src" "$HOME/.config/nvim/lua/plugins/$(basename "$src")" && ((changes++)) || true
done
for src in "$SCRIPT_DIR/configs/nvim/plugin/after/"*; do
    [[ -f "$src" ]] || continue
    deploy "$src" "$HOME/.config/nvim/plugin/after/$(basename "$src")" && ((changes++)) || true
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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
else
    skip "Oh My Zsh already installed"
fi

# Install zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
else
    skip "zsh-autosuggestions already installed"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting installed"
else
    skip "zsh-syntax-highlighting already installed"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/autoswitch_virtualenv" ]]; then
    git clone https://github.com/MichaelAqworthy/zsh-autoswitch-virtualenv "$ZSH_CUSTOM/plugins/autoswitch_virtualenv"
    ok "autoswitch_virtualenv installed"
else
    skip "autoswitch_virtualenv already installed"
fi

# Deploy .zshrc only if different
if [[ -f "$HOME/.zshrc" ]] && cmp -s "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"; then
    skip ".zshrc already up to date"
else
    cp "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"
    ok ".zshrc deployed"
fi

# Set zsh as default shell if not already
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
    ok "Default shell set to zsh"
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
    if [[ -f "$HOME/.config/systemd/user/$f" ]] && cmp -s "$SCRIPT_DIR/systemd/$f" "$HOME/.config/systemd/user/$f"; then
        continue
    fi
    cp "$SCRIPT_DIR/systemd/$f" "$HOME/.config/systemd/user/"
    ((svc_changes++))
done

# Walker auto-restart drop-in
mkdir -p "$HOME/.config/systemd/user/app-walker@autostart.service.d"
if ! cmp -s "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" "$HOME/.config/systemd/user/app-walker@autostart.service.d/restart.conf" 2>/dev/null; then
    cp "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" "$HOME/.config/systemd/user/app-walker@autostart.service.d/"
    ((svc_changes++))
fi

if [[ $svc_changes -gt 0 ]]; then
    systemctl --user daemon-reload
    ok "$svc_changes systemd unit files updated"
else
    skip "Systemd unit files already up to date"
fi

# Enable wallpaper rotation timer if not already active
if systemctl --user is-enabled wallpaper-rotate.timer &>/dev/null; then
    skip "wallpaper-rotate.timer already enabled"
else
    systemctl --user enable --now wallpaper-rotate.timer
    ok "Wallpaper rotation enabled (every 20 minutes)"
fi

# Enable elephant audio service if not already enabled
if systemctl --user is-enabled elephant.service &>/dev/null; then
    skip "elephant.service already enabled"
else
    systemctl --user enable elephant.service
    ok "Elephant audio service enabled"
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
        wallust run "$DEFAULT_WALLPAPER" 2>/dev/null || warn "wallust color generation failed (may need display)"
        ok "Wallust colors generated"
    fi
fi

# ============================================================================
# Done!
# ============================================================================

echo ""
echo "============================================"
echo -e "  ${GREEN}Installation complete!${NC}"
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
echo ""
echo "  Next steps:"
echo "    1. Log out and back in (or reboot)"
echo "    2. If monitors look wrong, edit:"
echo "       ~/.config/hypr/monitors.conf"
echo ""
