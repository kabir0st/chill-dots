#!/bin/bash
# os/pika.sh — PikaOS (Debian-based): pikman/apt install, pipx helper,
# JetBrainsMono Nerd Font download (no Debian package exists for it).

preflight_pika() {
    if ! command -v apt-get &>/dev/null; then
        err "apt-get not found — is this PikaOS/Debian?"
        exit 1
    fi
    if module_selected compositor-niri && ! command -v niri &>/dev/null; then
        warn "niri not found — compositor-niri configs will deploy but do nothing until niri is installed."
    fi
}

# Host packages go through apt. NOT pikman: despite the name, pikman is
# PikaOS's *container* package manager (apx-style — it has init/enter/run
# subcommands and installs into a managed container), so `pikman install zsh`
# never puts zsh on the host and fails outright when no container exists.
pkg_install_pika() {
    local pkg="$1"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" >>"$PKG_LOG" 2>&1
}

# One apt transaction for the whole list — far faster than N invocations, each
# of which takes the dpkg lock and rebuilds caches. install_packages falls back
# to per-package installs when this fails, so a single bad name never blocks
# the rest.
pkg_install_many_pika() {
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" >>"$PKG_LOG" 2>&1
}

NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"

# NB: never end one of these pipes with `grep -q`. It exits at the first match,
# fc-list upstream takes a SIGPIPE, and `set -o pipefail` turns the resulting
# 141 into a failure — so the check reports "not installed" precisely when the
# font IS installed. Plain `grep >/dev/null` drains its input and stays honest.
have_nerd_font() {
    fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" >/dev/null
}

pika_install_nerd_font() {
    if have_nerd_font; then
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
        [[ -d "$fontdir" ]] || journal created-tree "$fontdir"
        mkdir -p "$fontdir"
        unzip -oq "$tmp/JetBrainsMono.zip" -d "$fontdir"
        # Rebuild the whole user font cache, not just this directory: a
        # per-directory refresh leaves fc-list reading the stale global cache,
        # which used to make a perfectly good install report failure.
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
        if have_nerd_font; then
            ok "JetBrainsMono Nerd Font installed to ~/.local/share/fonts"
        elif compgen -G "$fontdir/*.ttf" >/dev/null; then
            ok "JetBrainsMono Nerd Font installed to $fontdir (fontconfig will pick it up at next login)"
        else
            warn "Nerd font download extracted nothing — check $fontdir"
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
        journal pipx waypaper
        ok "waypaper installed to ~/.local/bin/waypaper"
    else
        warn "pipx install waypaper failed — run manually: pipx install --system-site-packages waypaper"
    fi
}
