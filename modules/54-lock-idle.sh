#!/bin/bash
# Module: lock-idle — hypridle + hyprlock. Default on Arch. On PikaOS this is
# OFF by default because the live setup locks via pikabar-lock; selecting it
# explicitly deploys a niri-adapted hypridle config (still pikabar-lock, with
# `niri msg` instead of hyprctl) and leaves hyprlock alone.

register_module lock-idle "Idle daemon + lock screen (hypridle/hyprlock)" on off

mod_lock_idle_packages() {
    case "$CDOTS_OS" in
        arch) printf '%s\n' hyprlock hypridle ;;
        pika) echo hypridle ;;
    esac
}

mod_lock_idle_deploy() {
    if [[ "$CDOTS_OS" == pika ]]; then
        deploy "$SCRIPT_DIR/configs/hypr/hypridle.pika.conf" "$HOME/.config/hypr/hypridle.conf"
        info "Lock screen stays pikabar-lock (hyprlock.conf untouched on PikaOS)"
    else
        deploy "$SCRIPT_DIR/configs/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
        deploy "$SCRIPT_DIR/configs/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
    fi
}
