#!/bin/bash
# os/pika.sh — PikaOS (Debian-based): pikman/apt install, pipx helper,
# JetBrainsMono Nerd Font download (no Debian package exists for it).

preflight_pika() {
    if ! command -v pikman &>/dev/null && ! command -v apt-get &>/dev/null; then
        err "Neither pikman nor apt-get found — is this PikaOS/Debian?"
        exit 1
    fi
    if module_selected compositor-niri && ! command -v niri &>/dev/null; then
        warn "niri not found — compositor-niri configs will deploy but do nothing until niri is installed."
    fi
}

pkg_install_pika() {
    local pkg="$1"
    if command -v pikman &>/dev/null; then
        sudo pikman install -y "$pkg" &>/dev/null
    else
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" &>/dev/null
    fi
}

NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"

pika_install_nerd_font() {
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        skip "JetBrainsMono Nerd Font already installed"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would download JetBrainsMono Nerd Font to ~/.local/share/fonts"
        return 0
    fi
    info "Downloading JetBrainsMono Nerd Font..."
    local tmp fontdir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    tmp="$(mktemp -d)"
    if curl -fsSL --retry 2 -o "$tmp/JetBrainsMono.zip" "$NERD_FONT_URL" &&
       unzip -tq "$tmp/JetBrainsMono.zip" >/dev/null 2>&1; then
        mkdir -p "$fontdir"
        unzip -oq "$tmp/JetBrainsMono.zip" -d "$fontdir"
        fc-cache -f "$fontdir" >/dev/null 2>&1 || true
        if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
            ok "JetBrainsMono Nerd Font installed to ~/.local/share/fonts"
        else
            warn "Nerd font extracted but fontconfig doesn't see it — check ~/.local/share/fonts and run fc-cache -f"
        fi
    else
        warn "Could not download JetBrainsMono Nerd Font (offline?) — terminals will fall back to the default monospace font. Retry later or grab JetBrainsMono.zip from https://github.com/ryanoasis/nerd-fonts/releases"
    fi
    rm -rf "$tmp"
}

pika_pipx_install_waypaper() {
    if command -v waypaper &>/dev/null || [[ -x "$HOME/.local/bin/waypaper" ]]; then
        skip "waypaper already installed"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would install waypaper via pipx (--system-site-packages)"
        return 0
    fi
    if ! command -v pipx &>/dev/null; then
        warn "pipx not available — install it, then run: pipx install --system-site-packages waypaper"
        return 1
    fi
    info "Installing waypaper via pipx..."
    if pipx install --system-site-packages waypaper >/dev/null 2>&1; then
        ok "waypaper installed to ~/.local/bin/waypaper"
    else
        warn "pipx install waypaper failed — run manually: pipx install --system-site-packages waypaper"
    fi
}
