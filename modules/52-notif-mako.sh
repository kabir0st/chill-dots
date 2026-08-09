#!/bin/bash
# Module: notif-mako — Mako notification daemon with wallust colors.
# Optional on PikaOS: pikabar already owns org.freedesktop.Notifications,
# and two daemons on that D-Bus name conflict.

register_module notif-mako "Mako notification daemon + wallust colors" on off

mod_notif_mako_packages() {
    case "$CDOTS_OS" in
        arch) echo mako ;;
        pika) echo mako-notifier ;;
    esac
}

render_mako_config() {
    if [[ "$CDOTS_OS" == pika ]]; then
        grep -v 'omarchy'
    else
        cat
    fi
}

mod_notif_mako_deploy() {
    deploy_rendered "$SCRIPT_DIR/configs/mako/config" "$HOME/.config/mako/config" render_mako_config
    # Placeholder so the wallust include is valid before the first render
    if [[ ! -f "$HOME/.config/mako/wallust-colors.conf" && "$DRY_RUN" != 1 ]]; then
        journal_dirs "$HOME/.config/mako"
        mkdir -p "$HOME/.config/mako"
        journal created "$HOME/.config/mako/wallust-colors.conf"
        touch "$HOME/.config/mako/wallust-colors.conf"
    fi
}

mod_notif_mako_post() {
    if [[ "$CDOTS_OS" == pika ]]; then
        warn "pikabar already provides notifications on this system — don't autostart mako unless you disable pikabar's notification service, or the two will fight over D-Bus"
    fi
    return 0
}
