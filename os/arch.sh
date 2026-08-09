#!/bin/bash
# os/arch.sh — Arch Linux: pacman + yay (AUR fallback), Omarchy preflight.

preflight_arch() {
    if ! command -v pacman &>/dev/null; then
        if [[ "$DRY_RUN" == 1 ]]; then
            warn "pacman not found — continuing because this is a dry run"
        else
            err "pacman not found — this doesn't look like Arch. Use --os pika for PikaOS/Debian."
            exit 1
        fi
    fi
    if module_selected compositor-hyprland && [[ ! -d "$HOME/.local/share/omarchy" ]]; then
        if [[ "$DRY_RUN" == 1 ]]; then
            warn "Omarchy not found — continuing because this is a dry run"
        else
            err "Omarchy not found (~/.local/share/omarchy). Install Omarchy first, or deselect compositor-hyprland."
            exit 1
        fi
    fi
}

ensure_yay() {
    command -v yay &>/dev/null && return 0
    [[ "$DRY_RUN" == 1 ]] && { dry "Would install yay (AUR helper)"; return 1; }
    info "Installing yay (AUR helper)..."
    if sudo pacman -S --needed --noconfirm git base-devel; then
        local tmpdir
        tmpdir=$(mktemp -d)
        if git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" &&
           (cd "$tmpdir/yay" && makepkg -si --noconfirm); then
            ok "yay installed"
        else
            err "Failed to build yay from AUR"
        fi
        rm -rf "$tmpdir"
    else
        err "Failed to install yay build dependencies"
    fi
    command -v yay &>/dev/null
}

# Try the official repos first; fall back to the AUR via yay.
pkg_install_arch() {
    local pkg="$1"
    if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
        return 0
    fi
    if command -v yay &>/dev/null || ensure_yay; then
        yay -S --needed --noconfirm "$pkg" &>/dev/null
    else
        return 1
    fi
}

# AUR-only package list — goes straight through yay.
install_aur_file() {
    local file="$1" pkg
    [[ -f "$file" ]] || { warn "Package list missing: $file"; return; }
    if ! command -v yay &>/dev/null && ! ensure_yay; then
        err "yay not available — skipping AUR packages from $(basename "$file")"
        return
    fi
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        if pacman -Qi "$pkg" &>/dev/null; then
            PKG_SKIPPED=$((PKG_SKIPPED + 1))
            continue
        fi
        if [[ "$DRY_RUN" == 1 ]]; then
            dry "Would install AUR package: $pkg"
            continue
        fi
        if yay -S --needed --noconfirm "$pkg" &>/dev/null; then
            PKG_INSTALLED=$((PKG_INSTALLED + 1))
        else
            warn "Failed to install AUR package: $pkg"
            PKG_FAILED=$((PKG_FAILED + 1))
        fi
    done < "$file"
}
