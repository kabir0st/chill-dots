#!/bin/bash
# Module: wallpaper-picker — Waypaper GUI (Super+Shift+W). Arch installs it
# from the AUR; PikaOS has no package, so it comes via pipx with system GTK
# bindings.

register_module wallpaper-picker "Waypaper GUI wallpaper picker" on on

mod_wallpaper_picker_packages() {
    case "$CDOTS_OS" in
        arch) echo waypaper ;;
        pika) printf '%s\n' pipx python3-gi gir1.2-gtk-3.0 gir1.2-gtk-4.0 ;;
    esac
}

render_waypaper_config() {
    local backend=awww
    [[ "$CDOTS_OS" == pika ]] && backend=swww
    sed -e "s|__HOME__|$HOME|g" -e "s|^backend = .*|backend = $backend|"
}

mod_wallpaper_picker_deploy() {
    deploy_rendered "$SCRIPT_DIR/configs/waypaper/config.ini" "$HOME/.config/waypaper/config.ini" render_waypaper_config
    deploy "$SCRIPT_DIR/configs/waypaper/style.css" "$HOME/.config/waypaper/style.css"
}

mod_wallpaper_picker_post() {
    if [[ "$CDOTS_OS" == pika ]]; then
        pika_pipx_install_waypaper
    fi
    return 0
}
