#!/bin/bash
# Module: wallpaper-rotation — systemd user timer that swaps the wallpaper
# (and re-themes everything) every 20 minutes. On PikaOS it also turns off
# pikabar's own wallpaper rotation so the two don't fight over swww.

register_module wallpaper-rotation "Wallpaper rotation every 20 min (systemd timer)" on on

mod_wallpaper_rotation_packages() {
    case "$CDOTS_OS" in
        arch) echo awww ;;
        pika) echo swww ;;
    esac
}

mod_wallpaper_rotation_deploy() {
    deploy_exec "$SCRIPT_DIR/bin/chill-wallpaper" "$HOME/.local/bin/chill-wallpaper"
    local svc_changes=0 f
    for f in wallpaper-rotate.timer wallpaper-rotate.service; do
        if deploy "$SCRIPT_DIR/systemd/$f" "$HOME/.config/systemd/user/$f"; then
            svc_changes=$((svc_changes + 1))
        fi
    done
    if [[ $svc_changes -gt 0 && "$DRY_RUN" != 1 ]]; then
        systemctl --user daemon-reload 2>/dev/null || warn "systemd daemon-reload failed — may need an active session"
    fi
}

mod_wallpaper_rotation_post() {
    if systemctl --user is-enabled wallpaper-rotate.timer &>/dev/null; then
        skip "wallpaper-rotate.timer already enabled"
    elif [[ "$DRY_RUN" == 1 ]]; then
        dry "Would enable wallpaper-rotate.timer"
    elif systemctl --user enable --now wallpaper-rotate.timer 2>/dev/null; then
        journal unit-on wallpaper-rotate.timer
        ok "Wallpaper rotation enabled (every 20 minutes)"
    else
        warn "Could not enable wallpaper-rotate.timer — enable manually after login"
    fi

    if [[ "$CDOTS_OS" == pika ]]; then
        pikabar_disable_random_wallpaper
    fi
    return 0
}

pikabar_disable_random_wallpaper() {
    local settings="$HOME/.config/pikabar/Settings.json"
    [[ -f "$settings" ]] || return 0
    if ! command -v jq &>/dev/null; then
        warn "jq not found — disable pikabar's wallpaper rotation manually: set randomWallpaper=false in $settings"
        return 0
    fi
    if [[ "$(jq -r '.randomWallpaper // empty' "$settings")" != "true" ]]; then
        skip "pikabar randomWallpaper already disabled"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would set randomWallpaper=false in pikabar Settings.json"
        return 0
    fi
    backup_path "$settings"
    local tmp
    tmp="$(mktemp)"
    if jq '.randomWallpaper = false' "$settings" > "$tmp" && [[ -s "$tmp" ]]; then
        mv "$tmp" "$settings"
        ok "Disabled pikabar's own wallpaper rotation (the chill-dots timer owns it now)"
    else
        rm -f "$tmp"
        warn "Could not update pikabar Settings.json — set randomWallpaper=false manually"
    fi
}
