#!/bin/bash
# Module: osd-swayosd — on-screen display for volume/brightness. On PikaOS
# the Omarchy theme @import is replaced with static fallback colors.

register_module osd-swayosd "SwayOSD volume/brightness overlay" on off

mod_osd_swayosd_packages() { echo swayosd; }

render_swayosd_style() {
    if [[ "$CDOTS_OS" == pika ]]; then
        awk '/@import/ {
            print "@define-color background-color rgba(15, 16, 23, 0.98);"
            print "@define-color border-color #89b4fa;"
            print "@define-color label #cdd6f4;"
            print "@define-color image #cdd6f4;"
            print "@define-color progress #89b4fa;"
            next
        } { print }'
    else
        cat
    fi
}

mod_osd_swayosd_deploy() {
    deploy "$SCRIPT_DIR/configs/swayosd/config.toml" "$HOME/.config/swayosd/config.toml"
    deploy_rendered "$SCRIPT_DIR/configs/swayosd/style.css" "$HOME/.config/swayosd/style.css" render_swayosd_style
}
