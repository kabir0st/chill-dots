#!/bin/bash
# ============================================================================
# chill_config installer
# Restores your full Hyprland/Omarchy rice on a fresh Arch + Omarchy install
#
# Usage: Clone this repo, install Omarchy first, then run:
#   chmod +x install.sh && ./install.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

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
echo "  chill_config installer"
echo "  Restoring your Hyprland/Omarchy rice"
echo "============================================"
echo ""

# ============================================================================
# Step 1: Install packages
# ============================================================================

info "Step 1/7: Installing packages..."

# Install yay if not present (needed for AUR packages)
if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    ok "yay installed"
fi

info "Installing official packages (this may take a while)..."
sudo pacman -S --needed --noconfirm - < "$SCRIPT_DIR/pkglist-official.txt" || warn "Some official packages failed to install"

info "Installing AUR packages..."
yay -S --needed --noconfirm - < "$SCRIPT_DIR/pkglist-aur.txt" || warn "Some AUR packages failed to install"

ok "Packages installed"

# ============================================================================
# Step 2: Backup existing configs
# ============================================================================

info "Step 2/7: Backing up existing configs to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

for dir in hypr waybar kitty ghostty mako walker swayosd waypaper wallust fastfetch btop tmux nvim; do
    if [[ -d "$HOME/.config/$dir" ]]; then
        cp -r "$HOME/.config/$dir" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done
[[ -f "$HOME/.config/starship.toml" ]] && cp "$HOME/.config/starship.toml" "$BACKUP_DIR/"
[[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$BACKUP_DIR/"

ok "Backup saved to $BACKUP_DIR"

# ============================================================================
# Step 3: Copy wallpapers
# ============================================================================

info "Step 3/7: Copying wallpapers..."
mkdir -p "$HOME/Pictures/Wallpapers"
cp -n "$SCRIPT_DIR/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
ok "Wallpapers copied to ~/Pictures/Wallpapers/ ($(ls "$SCRIPT_DIR/wallpapers/" | wc -l) files)"

# ============================================================================
# Step 4: Deploy config files
# ============================================================================

info "Step 4/7: Deploying config files..."

# Hyprland
mkdir -p "$HOME/.config/hypr/scripts" "$HOME/.config/hypr/wallust"
cp "$SCRIPT_DIR/configs/hypr/hyprland.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/looknfeel.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/bindings.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/monitors.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/input.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/autostart.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/hypridle.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/hyprlock.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/hyprsunset.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/xdph.conf" "$HOME/.config/hypr/"
cp "$SCRIPT_DIR/configs/hypr/scripts/wallpaper.sh" "$HOME/.config/hypr/scripts/"
chmod +x "$HOME/.config/hypr/scripts/wallpaper.sh"

# Wallust (auto-theming)
mkdir -p "$HOME/.config/wallust/templates"
cp "$SCRIPT_DIR/configs/wallust/wallust.toml" "$HOME/.config/wallust/"
cp "$SCRIPT_DIR/configs/wallust/templates/"* "$HOME/.config/wallust/templates/"

# Waybar
mkdir -p "$HOME/.config/waybar/scripts" "$HOME/.config/waybar/wallust"
cp "$SCRIPT_DIR/configs/waybar/config.jsonc" "$HOME/.config/waybar/"
cp "$SCRIPT_DIR/configs/waybar/style.css" "$HOME/.config/waybar/"
cp "$SCRIPT_DIR/configs/waybar/mocha.css" "$HOME/.config/waybar/"
cp "$SCRIPT_DIR/configs/waybar/scripts/waybar-wttr.py" "$HOME/.config/waybar/scripts/"
chmod +x "$HOME/.config/waybar/scripts/waybar-wttr.py"

# Kitty
mkdir -p "$HOME/.config/kitty"
cp "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/"

# Ghostty (if config exists)
if [[ -f "$SCRIPT_DIR/configs/ghostty/config" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    cp "$SCRIPT_DIR/configs/ghostty/config" "$HOME/.config/ghostty/"
fi

# Mako
mkdir -p "$HOME/.config/mako"
cp "$SCRIPT_DIR/configs/mako/config" "$HOME/.config/mako/"

# Starship
cp "$SCRIPT_DIR/configs/starship/starship.toml" "$HOME/.config/starship.toml"

# Walker
mkdir -p "$HOME/.config/walker/themes"
cp "$SCRIPT_DIR/configs/walker/config.toml" "$HOME/.config/walker/"

# SwayOSD
mkdir -p "$HOME/.config/swayosd"
cp "$SCRIPT_DIR/configs/swayosd/config.toml" "$HOME/.config/swayosd/"
cp "$SCRIPT_DIR/configs/swayosd/style.css" "$HOME/.config/swayosd/"

# Waypaper
mkdir -p "$HOME/.config/waypaper"
cp "$SCRIPT_DIR/configs/waypaper/config.ini" "$HOME/.config/waypaper/"
# Fix waypaper paths to use current user's home
sed -i "s|/home/lurayy|$HOME|g" "$HOME/.config/waypaper/config.ini"

# Omarchy hooks & extensions
mkdir -p "$HOME/.config/omarchy/hooks" "$HOME/.config/omarchy/extensions"
cp "$SCRIPT_DIR/configs/omarchy/hooks/theme-set" "$HOME/.config/omarchy/hooks/"
cp "$SCRIPT_DIR/configs/omarchy/extensions/menu.sh" "$HOME/.config/omarchy/extensions/"
chmod +x "$HOME/.config/omarchy/hooks/theme-set"

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"
cp "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"
cp "$SCRIPT_DIR/configs/fastfetch/logo.txt" "$HOME/.config/fastfetch/"

# Btop
mkdir -p "$HOME/.config/btop"
cp "$SCRIPT_DIR/configs/btop/btop.conf" "$HOME/.config/btop/"

# Tmux
mkdir -p "$HOME/.config/tmux"
cp "$SCRIPT_DIR/configs/tmux/tmux.conf" "$HOME/.config/tmux/"

# Neovim (LazyVim)
mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins" "$HOME/.config/nvim/plugin/after"
cp "$SCRIPT_DIR/configs/nvim/init.lua" "$HOME/.config/nvim/"
cp "$SCRIPT_DIR/configs/nvim/lazy-lock.json" "$HOME/.config/nvim/"
cp "$SCRIPT_DIR/configs/nvim/lazyvim.json" "$HOME/.config/nvim/"
cp "$SCRIPT_DIR/configs/nvim/stylua.toml" "$HOME/.config/nvim/"
cp "$SCRIPT_DIR/configs/nvim/lua/config/"* "$HOME/.config/nvim/lua/config/"
cp "$SCRIPT_DIR/configs/nvim/lua/plugins/"* "$HOME/.config/nvim/lua/plugins/"
cp "$SCRIPT_DIR/configs/nvim/plugin/after/"* "$HOME/.config/nvim/plugin/after/"

ok "Config files deployed"

# ============================================================================
# Step 5: Shell setup (zsh + oh-my-zsh + plugins + starship)
# ============================================================================

info "Step 5/7: Setting up shell..."

# Install oh-my-zsh if not present
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
fi

# Install zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/autoswitch_virtualenv" ]]; then
    git clone https://github.com/MichaelAqworthy/zsh-autoswitch-virtualenv "$ZSH_CUSTOM/plugins/autoswitch_virtualenv"
fi

# Deploy .zshrc
cp "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"

# Set zsh as default shell if not already
if [[ "$SHELL" != *"zsh"* ]]; then
    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
fi

ok "Shell configured"

# ============================================================================
# Step 6: Systemd user services
# ============================================================================

info "Step 6/7: Setting up systemd services..."

mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/systemd/wallpaper-rotate.timer" "$HOME/.config/systemd/user/"
cp "$SCRIPT_DIR/systemd/wallpaper-rotate.service" "$HOME/.config/systemd/user/"
cp "$SCRIPT_DIR/systemd/elephant.service" "$HOME/.config/systemd/user/"

# Walker auto-restart drop-in
mkdir -p "$HOME/.config/systemd/user/app-walker@autostart.service.d"
cp "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" "$HOME/.config/systemd/user/app-walker@autostart.service.d/"

systemctl --user daemon-reload

# Enable wallpaper rotation timer
systemctl --user enable --now wallpaper-rotate.timer
ok "Wallpaper rotation enabled (every 20 minutes)"

# Enable elephant audio service
systemctl --user enable elephant.service
ok "Elephant audio service enabled"

# Disable the systemd waybar service to prevent duplicate waybar instances
# (Hyprland autostart already launches waybar)
systemctl --user disable waybar.service 2>/dev/null || true
ok "Disabled duplicate waybar.service"

ok "Systemd services configured"

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
    ln -sf "$DEFAULT_WALLPAPER" "$HOME/.config/omarchy/current/background"
    ok "Default wallpaper set to Lofi_Cat.png"
fi

# Generate wallust colors from the wallpaper
if command -v wallust &>/dev/null && [[ -f "$DEFAULT_WALLPAPER" ]]; then
    info "Generating wallust color scheme from wallpaper..."
    mkdir -p "$HOME/.cache/wallust"
    wallust run "$DEFAULT_WALLPAPER" 2>/dev/null || warn "wallust color generation failed (may need display)"
    ok "Wallust colors generated"
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
echo "    - Theme: $THEME_NAME"
echo ""
echo "  Next steps:"
echo "    1. Log out and back in (or reboot)"
echo "    2. If monitors look wrong, edit:"
echo "       ~/.config/hypr/monitors.conf"
echo "    3. Your old configs are backed up at:"
echo "       $BACKUP_DIR"
echo ""
