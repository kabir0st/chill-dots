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

    # Keybinds. Binds merge positionally too, so a bind defined in a later
    # include replaces the same chord from the main config (verified with
    # niri validate). Flag any takeover so it isn't a surprise.
    local taken=()
    local chord
    for chord in 'Mod\+Shift\+R' 'Mod\+Shift\+W' 'Mod\+Shift\+Return' 'Mod\+O'; do
        if grep -qE "^[[:space:]]*${chord}([[:space:]]|\{|$)" "$NIRI_CONFIG"; then
            taken+=("$(echo "$chord" | sed 's/\\//g')")
        fi
    done
    if [[ ${#taken[@]} -gt 0 ]]; then
        info "${taken[*]} already bound in config.kdl — the chill-dots binds take over (remove the chill-bindings.kdl include to undo)"
    fi
    # The browser bind resolves your default browser at run time.
    deploy_exec "$SCRIPT_DIR/bin/chill-browser" "$HOME/.local/bin/chill-browser"
    deploy "$SCRIPT_DIR/configs/niri/chill-bindings.kdl" "$HOME/.config/niri/chill-bindings.kdl"
    niri_add_include "chill-bindings.kdl"
}

# Rewrite config.kdl through a filter (stdin -> stdout), then let niri check
# the result and put the original back if it complains. The pre-run copy also
# goes to the run directory, so `--rollback` undoes the edit later.
# Used by this module and by the clipboard module.
niri_safe_edit() {
    local description="$1" filter="$2" saved rc=0
    [[ -f "$NIRI_CONFIG" ]] || return 1
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would $description"
        CHANGES=$((CHANGES + 1))
        return 0
    fi
    backup_path "$NIRI_CONFIG" || return 1
    saved="$(mktemp)" || { err "mktemp failed"; return 1; }
    cp "$NIRI_CONFIG" "$saved"
    if ! "$filter" < "$saved" > "$NIRI_CONFIG"; then
        cp "$saved" "$NIRI_CONFIG"
        err "Failed to $description — config.kdl left unchanged"
        rc=1
    elif command -v niri &>/dev/null && ! niri validate -c "$NIRI_CONFIG" &>/dev/null; then
        cp "$saved" "$NIRI_CONFIG"
        err "niri rejected config.kdl after '$description' — change rolled back"
        rc=1
    else
        ok "$description"
        CHANGES=$((CHANGES + 1))
    fi
    rm -f "$saved"
    return $rc
}

# Append `include "<file>"` at the end of config.kdl, validate, roll back on
# rejection. Idempotent: skipped when the include is already there.
niri_add_include() {
    local name="$1"
    # Match the include directive itself, not the filename anywhere in the
    # file: a comment mentioning the file (the clipboard module writes one)
    # would otherwise look like the include is already there, and the real
    # include would never be added.
    if grep -qE "^[[:space:]]*include[[:space:]]+\"$name\"" "$NIRI_CONFIG"; then
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
