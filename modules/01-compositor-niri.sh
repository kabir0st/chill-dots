#!/bin/bash
# Module: compositor-niri — wallpaper-driven border colors + wallpaper keybinds
# for niri (PikaOS). Works through config.kdl includes (niri >= 25.11): the
# user's config.kdl gets at most two appended `include` lines and is never
# otherwise modified. niri merges includes positionally — later wins — so an
# include appended at the end overrides the stock border colors.

register_module compositor-niri "niri: wallust border colors + wallpaper keybinds (via includes)" na on

NIRI_CONFIG="$HOME/.config/niri/config.kdl"

mod_compositor_niri_deploy() {
    # Stub keeps the include valid before wallust first runs; wallust
    # overwrites this file on every wallpaper change.
    if [[ -f "$HOME/.config/niri/wallust-colors.kdl" ]]; then
        skip "niri wallust-colors.kdl already present"
    else
        deploy "$SCRIPT_DIR/configs/niri/wallust-colors.stub.kdl" "$HOME/.config/niri/wallust-colors.kdl"
    fi

    if [[ ! -f "$NIRI_CONFIG" ]]; then
        warn "No niri config found at $NIRI_CONFIG — skipping include setup"
        return 0
    fi

    niri_add_include "wallust-colors.kdl"

    # Wallpaper keybinds. Binds merge positionally too, so a bind defined in a
    # later include replaces the same chord from the main config (verified with
    # niri validate). Flag any takeover so it isn't a surprise.
    if grep -qE '^[[:space:]]*Mod\+Shift\+(R|W)([[:space:]]|\{|$)' "$NIRI_CONFIG"; then
        info "Mod+Shift+R/W were bound in config.kdl — the chill-dots wallpaper binds take over (remove the chill-bindings.kdl include to undo)"
    fi
    deploy "$SCRIPT_DIR/configs/niri/chill-bindings.kdl" "$HOME/.config/niri/chill-bindings.kdl"
    niri_add_include "chill-bindings.kdl"
}

# Append `include "<file>"` at the end of config.kdl, validate, roll back on
# rejection. Idempotent: skipped when the include is already there.
niri_add_include() {
    local name="$1"
    if grep -qF "$name" "$NIRI_CONFIG"; then
        skip "config.kdl already includes $name"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would append to config.kdl: include \"$name\""
        CHANGES=$((CHANGES + 1))
        return 0
    fi
    backup_path "$NIRI_CONFIG"
    local saved
    saved="$(mktemp)"
    cp "$NIRI_CONFIG" "$saved"
    {
        echo ""
        echo "// Chill-dots — later includes override earlier settings"
        echo "include \"$name\""
    } >> "$NIRI_CONFIG"
    if command -v niri &>/dev/null && ! niri validate -c "$NIRI_CONFIG" &>/dev/null; then
        cp "$saved" "$NIRI_CONFIG"
        err "niri rejected config.kdl after adding include \"$name\" — change rolled back"
    else
        ok "Added include \"$name\" to config.kdl"
        CHANGES=$((CHANGES + 1))
    fi
    rm -f "$saved"
}
