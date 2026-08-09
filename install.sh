#!/bin/bash
# ============================================================================
# Chill Dots installer — Arch/Omarchy (Hyprland) and PikaOS (niri)
#
# Interactive by default: pick the components you want, see exactly which
# packages get installed and which files get replaced (with per-run backups)
# before anything happens.
#
# Usage:
#   ./install.sh                       interactive install (auto-detects OS)
#   ./install.sh --list-modules        show available components for this OS
#   ./install.sh --dry-run             show what would change, write nothing
#   ./install.sh --non-interactive --profile pika-default
#   ./install.sh --os arch --modules terminal-kitty,shell-zsh
#
# Options:
#   --os arch|pika       Override OS detection
#   --profile NAME       Use a module set from profiles/NAME.txt
#   --modules a,b,c      Install exactly these modules
#   --all                Install every module available on this OS
#   --non-interactive    No prompts; defaults used unless told otherwise
#   --dry-run            Print planned actions without changing anything
#   --skip-packages      Skip all package installation
#   --list-modules       List modules for this OS and exit
#
# Safe to re-run: every step checks actual state before acting.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
SKIP_PACKAGES=0
NON_INTERACTIVE=0
SELECT_ALL=0
PROFILE=""
MODULES_ARG=""
OS_OVERRIDE=""
LIST_MODULES=0

usage() {
    sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --os)               OS_OVERRIDE="${2:-}"; shift 2 ;;
        --os=*)             OS_OVERRIDE="${1#*=}"; shift ;;
        --profile)          PROFILE="${2:-}"; shift 2 ;;
        --profile=*)        PROFILE="${1#*=}"; shift ;;
        --modules)          MODULES_ARG="${2:-}"; shift 2 ;;
        --modules=*)        MODULES_ARG="${1#*=}"; shift ;;
        --all)              SELECT_ALL=1; shift ;;
        --non-interactive)  NON_INTERACTIVE=1; shift ;;
        --dry-run)          DRY_RUN=1; shift ;;
        --skip-packages)    SKIP_PACKAGES=1; shift ;;
        --list-modules)     LIST_MODULES=1; shift ;;
        -h|--help)          usage; exit 0 ;;
        *)                  echo "Unknown option: $1"; echo ""; usage; exit 1 ;;
    esac
done

# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=lib/os.sh
source "$SCRIPT_DIR/lib/os.sh"
# shellcheck source=lib/registry.sh
source "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=os/arch.sh
source "$SCRIPT_DIR/os/arch.sh"
# shellcheck source=os/pika.sh
source "$SCRIPT_DIR/os/pika.sh"

for module_file in "$SCRIPT_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$module_file"
done
unset module_file

detect_os

if [[ "$LIST_MODULES" == 1 ]]; then
    list_modules
    exit 0
fi

echo ""
echo "============================================"
echo "  Chill Dots installer  ($CDOTS_OS)"
[[ "$DRY_RUN" == 1 ]] && echo "  DRY RUN — nothing will be changed"
echo "============================================"

resolve_selection

case "$CDOTS_OS" in
    arch) preflight_arch ;;
    pika) preflight_pika ;;
esac

preview_selection
confirm_proceed

for module_id in "${SELECTED_MODULES[@]}"; do
    run_module "$module_id"
done
unset module_id

# ============================================================================
# Finalize — theme + first color generation (runs after all modules so the
# wallpapers and templates are guaranteed to be in place)
# ============================================================================

finalize() {
    local default_wallpaper="$HOME/Pictures/Wallpapers/Lofi_Cat.png"

    if [[ "$CDOTS_OS" == arch ]] && module_selected compositor-hyprland; then
        local theme_name="klein-cosmic"
        [[ -f "$SCRIPT_DIR/configs/omarchy/theme.name" ]] && theme_name="$(cat "$SCRIPT_DIR/configs/omarchy/theme.name")"
        if [[ "$DRY_RUN" == 1 ]]; then
            dry "Would apply omarchy theme: $theme_name"
        elif command -v omarchy-theme-set &>/dev/null; then
            omarchy-theme-set "$theme_name" 2>/dev/null || warn "Could not set theme (may need an active Hyprland session)"
        else
            warn "omarchy-theme-set not found — set the theme manually after login"
        fi

        if [[ -f "$default_wallpaper" ]]; then
            local current_target
            current_target=$(readlink -f "$HOME/.config/omarchy/current/background" 2>/dev/null || echo "")
            if [[ "$current_target" == "$default_wallpaper" ]]; then
                skip "Default wallpaper symlink already set"
            elif [[ "$DRY_RUN" == 1 ]]; then
                dry "Would set default wallpaper symlink to Lofi_Cat.png"
            else
                mkdir -p "$HOME/.config/omarchy/current"
                ln -sf "$default_wallpaper" "$HOME/.config/omarchy/current/background"
                ok "Default wallpaper set to Lofi_Cat.png"
            fi
        fi
    fi

    if module_selected theming-wallust; then
        local wallpaper=""
        [[ -f "$HOME/.cache/wallust/current_wallpaper" ]] && wallpaper="$(cat "$HOME/.cache/wallust/current_wallpaper")"
        [[ -f "$wallpaper" ]] || wallpaper="$default_wallpaper"
        if [[ "$DRY_RUN" == 1 && ! -f "$wallpaper" ]] && module_selected wallpapers; then
            dry "Would generate wallust colors from the default wallpaper"
        elif [[ ! -f "$wallpaper" ]]; then
            warn "No wallpaper found to generate colors from — run: chill-wallpaper random"
        elif [[ "$DRY_RUN" == 1 ]]; then
            dry "Would generate wallust colors from $(basename "$wallpaper")"
        elif command -v wallust &>/dev/null; then
            info "Generating wallust colors from $(basename "$wallpaper")..."
            if wallust run "$wallpaper" 2>/dev/null; then
                ok "Wallust colors generated"
            else
                warn "wallust color generation failed — run manually: chill-wallpaper random"
            fi
        else
            warn "wallust not installed — colors will generate on the first wallpaper change"
        fi
    fi
}

echo ""
info "── finalize ──"
finalize

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================"
if [[ "$DRY_RUN" == 1 ]]; then
    echo -e "  ${YELLOW}Dry run complete${NC} — $CHANGES file change(s) pending, nothing written"
elif [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}Installation complete!${NC}"
else
    echo -e "  ${YELLOW}Installation complete with ${#ISSUES[@]} issue(s)${NC}"
fi
echo "============================================"
echo ""
echo "  Modules installed: ${SELECTED_MODULES[*]}"
if [[ "$SKIP_PACKAGES" != 1 && $((PKG_INSTALLED + PKG_FAILED + PKG_SKIPPED)) -gt 0 ]]; then
    echo "  Packages: $PKG_INSTALLED installed, $PKG_SKIPPED already present, $PKG_FAILED failed"
fi
[[ -n "$BACKUP_DIR" ]] && echo "  Replaced files backed up to: $BACKUP_DIR"

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
if [[ "$CDOTS_OS" == arch ]]; then
    echo "    2. If monitors look wrong, edit ~/.config/hypr/monitors.conf"
else
    echo "    2. Set a wallpaper + colors: ~/.local/bin/chill-wallpaper random"
fi
echo ""
