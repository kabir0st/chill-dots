#!/bin/bash
# Module: clipboard-cursor-clip — Windows-style clipboard history for niri.
#
# cursor-clip <https://github.com/Sirulex/cursor-clip> is a GTK4 layer-shell
# popup: a daemon watches the clipboard, and Mod+V (the Win+V muscle memory)
# opens the history. There's no Debian package, so the prebuilt release binary
# is downloaded and checksum-verified into ~/.local/bin.
#
# niri wiring is three separate edits, each validated with `niri validate`:
# the keybind lives in its own include (so nothing else can clobber it), the
# daemon is autostarted from config.kdl, and niri's stock Mod+V
# (toggle-window-floating) is moved aside to Mod+Ctrl+V.

register_module clipboard-cursor-clip "Clipboard history popup on Mod+V (cursor-clip)" na on

CURSOR_CLIP_REPO="Sirulex/cursor-clip"
CURSOR_CLIP_BIN="$HOME/.local/bin/cursor-clip"
CURSOR_CLIP_SPAWN='spawn-at-startup "sh" "-c" "$HOME/.local/bin/cursor-clip --daemon"'

mod_clipboard_cursor_clip_packages() {
    # The GTK4 layer-shell runtime the popup links against.
    case "$CDOTS_OS" in
        pika) echo libgtk4-layer-shell0 ;;
        arch) echo gtk4-layer-shell ;;
    esac
}

mod_clipboard_cursor_clip_deploy() {
    deploy "$SCRIPT_DIR/configs/cursor-clip/config.toml" "$HOME/.config/cursor-clip/config.toml"
    deploy "$SCRIPT_DIR/configs/niri/clipboard-bindings.kdl" "$HOME/.config/niri/clipboard-bindings.kdl"
}

mod_clipboard_cursor_clip_post() {
    cursor_clip_install_binary || return 0
    cursor_clip_wire_niri
    cursor_clip_start_daemon
    return 0
}

# ---------------------------------------------------------------- binary ----

cursor_clip_arch() {
    case "$(uname -m)" in
        x86_64)        echo x86_64-unknown-linux-gnu ;;
        aarch64|arm64) echo aarch64-unknown-linux-gnu ;;
        *)             return 1 ;;
    esac
}

cursor_clip_install_binary() {
    if [[ -x "$CURSOR_CLIP_BIN" ]]; then
        skip "cursor-clip already installed at ~/.local/bin/cursor-clip"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would download the latest cursor-clip release to ~/.local/bin/cursor-clip"
        CHANGES=$((CHANGES + 1))
        return 0
    fi

    local arch
    if ! arch="$(cursor_clip_arch)"; then
        warn "No prebuilt cursor-clip for $(uname -m) — build it from source: https://github.com/$CURSOR_CLIP_REPO"
        return 1
    fi
    if ! command -v curl &>/dev/null; then
        warn "curl not available — cannot download cursor-clip"
        return 1
    fi

    # sed rather than `grep -m1`: an early-exiting reader would SIGPIPE curl,
    # and pipefail would then report the whole pipeline as failed.
    local tag
    tag="$(curl -fsSL "https://api.github.com/repos/$CURSOR_CLIP_REPO/releases/latest" 2>/dev/null |
           sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p')"
    if [[ -z "$tag" ]]; then
        warn "Could not reach GitHub to find the latest cursor-clip release — skipping (re-run later)"
        return 1
    fi

    local tmp tarball base
    tmp="$(mktemp -d)" || return 1
    tarball="cursor-clip-$tag-$arch.tar.gz"
    base="https://github.com/$CURSOR_CLIP_REPO/releases/download/$tag"

    info "Downloading cursor-clip $tag..."
    if ! curl -fsSL "$base/$tarball" -o "$tmp/$tarball" ||
       ! curl -fsSL "$base/$tarball.sha256" -o "$tmp/$tarball.sha256"; then
        warn "Download failed for cursor-clip $tag — skipping"
        rm -rf "$tmp"
        return 1
    fi

    local want have
    want="$(cut -d' ' -f1 < "$tmp/$tarball.sha256")"
    have="$(sha256sum "$tmp/$tarball" | cut -d' ' -f1)"
    if [[ -z "$want" || "$want" != "$have" ]]; then
        err "Checksum mismatch for $tarball — expected $want, got $have. Not installing."
        rm -rf "$tmp"
        return 1
    fi

    local src
    if ! tar -xzf "$tmp/$tarball" -C "$tmp" ||
       ! src="$(find "$tmp" -type f -name cursor-clip -print -quit)" || [[ -z "$src" ]]; then
        warn "No cursor-clip binary inside $tarball"
        rm -rf "$tmp"
        return 1
    fi

    ensure_dir "$HOME/.local/bin"
    journal created "$CURSOR_CLIP_BIN"
    install -m 0755 "$src" "$CURSOR_CLIP_BIN"
    rm -rf "$tmp"
    CHANGES=$((CHANGES + 1))
    ok "cursor-clip $tag installed (checksum verified)"

    # A missing layer-shell library shows up as a popup that never appears,
    # which is a miserable thing to debug later.
    if ldd "$CURSOR_CLIP_BIN" 2>/dev/null | grep -F 'not found' >/dev/null; then
        warn "cursor-clip has unresolved libraries — install the GTK4 layer-shell runtime and re-run:"
        ldd "$CURSOR_CLIP_BIN" 2>/dev/null | grep 'not found' | sed 's/^/         /'
    fi
    return 0
}

# ------------------------------------------------------------ niri wiring ----

# niri ships Mod+V as toggle-window-floating; move it out of the way rather
# than silently shadowing it, and leave a comment saying where it went.
cursor_clip_move_floating_bind() {
    sed -E 's|^([[:space:]]*)Mod\+V([[:space:]]*)\{([[:space:]]*)toggle-window-floating|\1// Mod+V is the clipboard history popup (see clipboard-bindings.kdl)\n\1Mod+Ctrl+V\2{\3toggle-window-floating|'
}

# Put the daemon next to the other spawn-at-startup lines, or at the end when
# there aren't any.
cursor_clip_add_spawn() {
    awk -v line="$CURSOR_CLIP_SPAWN" '
        { l[NR] = $0; if ($0 ~ /^spawn-at-startup/) last = NR }
        END {
            for (i = 1; i <= NR; i++) { print l[i]; if (i == last) print line }
            if (!last) print line
        }'
}

cursor_clip_wire_niri() {
    if [[ ! -f "$NIRI_CONFIG" ]]; then
        warn "No niri config at $NIRI_CONFIG — bind Mod+V to cursor-clip and autostart 'cursor-clip --daemon' yourself"
        return 0
    fi

    if grep -qE '^[[:space:]]*Mod\+V[[:space:]]*\{[[:space:]]*toggle-window-floating' "$NIRI_CONFIG"; then
        niri_safe_edit "move niri's Mod+V (toggle floating) to Mod+Ctrl+V" cursor_clip_move_floating_bind
    else
        skip "Mod+V is already free in config.kdl"
    fi

    if grep -qF 'cursor-clip --daemon' "$NIRI_CONFIG"; then
        skip "cursor-clip daemon autostart already in config.kdl"
    else
        niri_safe_edit "autostart the cursor-clip daemon" cursor_clip_add_spawn
    fi

    niri_add_include "clipboard-bindings.kdl"
}

# ------------------------------------------------------------- the daemon ----

cursor_clip_start_daemon() {
    [[ "$DRY_RUN" == 1 ]] && return 0
    [[ -x "$CURSOR_CLIP_BIN" ]] || return 0

    # -x matches the executable name: matching the full command line would also
    # hit the shell that holds it as an argument, and report a false success.
    if pgrep -x cursor-clip >/dev/null 2>&1; then
        skip "cursor-clip daemon already running"
        return 0
    fi
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        info "cursor-clip will start with niri at your next login (no Wayland session here to attach to)"
        return 0
    fi
    setsid "$CURSOR_CLIP_BIN" --daemon >/dev/null 2>&1 &
    sleep 2
    if pgrep -x cursor-clip >/dev/null 2>&1; then
        ok "cursor-clip daemon running — copy something, then press Mod+V"
    else
        warn "cursor-clip daemon exited immediately — try running it by hand: cursor-clip --daemon"
    fi
    return 0
}
