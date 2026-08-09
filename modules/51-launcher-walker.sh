#!/bin/bash
# Module: launcher-walker — Walker app launcher + Elephant provider backend.
# Default on Arch (Omarchy build); optional on PikaOS where pikabar's
# launcher owns Mod+D.

register_module launcher-walker "Walker app launcher + Elephant backend" on off

mod_launcher_walker_packages() {
    case "$CDOTS_OS" in
        arch) echo omarchy-walker ;;
        pika) printf '%s\n' walker elephant elephant-chungus ;;
    esac
}

render_walker_config() {
    if [[ "$CDOTS_OS" == pika ]]; then
        sed -e '/^theme = /d' \
            -e '/^additional_theme_location/d' \
            -e 's/omarchy-restart-walker/pkill walker/'
    else
        cat
    fi
}

mod_launcher_walker_deploy() {
    deploy_rendered "$SCRIPT_DIR/configs/walker/config.toml" "$HOME/.config/walker/config.toml" render_walker_config
    if deploy "$SCRIPT_DIR/systemd/elephant.service" "$HOME/.config/systemd/user/elephant.service"; then
        [[ "$DRY_RUN" == 1 ]] || systemctl --user daemon-reload 2>/dev/null || true
    fi
    if [[ "$CDOTS_OS" == arch ]]; then
        deploy "$SCRIPT_DIR/systemd/app-walker-autostart.service.d/restart.conf" \
               "$HOME/.config/systemd/user/app-walker@autostart.service.d/restart.conf"
    fi
}

mod_launcher_walker_post() {
    if systemctl --user is-enabled elephant.service &>/dev/null; then
        skip "elephant.service already enabled"
    elif [[ "$DRY_RUN" == 1 ]]; then
        dry "Would enable elephant.service"
    elif systemctl --user enable elephant.service 2>/dev/null; then
        journal unit-on elephant.service
        ok "Elephant service enabled"
    else
        warn "Could not enable elephant.service — enable manually after login"
    fi
    if [[ "$CDOTS_OS" == pika ]]; then
        info "Mod+D stays pikabar's launcher — bind walker yourself if preferred (niri bind: spawn \"walker\")"
    fi
    return 0
}
