#!/bin/bash
# Module: bar-waybar — Waybar status bar (weather, stats, tray) themed by
# wallust. Default on Arch; optional on PikaOS where pikabar owns the bar.

register_module bar-waybar "Waybar status bar (weather, stats) + wallust colors" on off

mod_bar_waybar_packages() { echo waybar; }

mod_bar_waybar_deploy() {
    local f
    for f in config.jsonc style.css mocha.css; do
        deploy "$SCRIPT_DIR/configs/waybar/$f" "$HOME/.config/waybar/$f"
    done
    deploy_exec "$SCRIPT_DIR/configs/waybar/scripts/waybar-wttr.py" "$HOME/.config/waybar/scripts/waybar-wttr.py"
    # Fallback palette until wallust first runs — waybar fails hard on a
    # missing @import, and style.css imports wallust/colors-waybar.css.
    if [[ ! -f "$HOME/.config/waybar/wallust/colors-waybar.css" ]]; then
        deploy "$SCRIPT_DIR/configs/waybar/wallust-colors-default.css" "$HOME/.config/waybar/wallust/colors-waybar.css"
    fi
}

mod_bar_waybar_post() {
    if [[ "$CDOTS_OS" == arch ]]; then
        # Omarchy autostarts waybar; the systemd unit would duplicate it
        if systemctl --user is-enabled waybar.service &>/dev/null; then
            if [[ "$DRY_RUN" == 1 ]]; then
                dry "Would disable duplicate waybar.service"
            else
                systemctl --user disable waybar.service 2>/dev/null || true
                journal unit-off waybar.service
                ok "Disabled duplicate waybar.service"
            fi
        else
            skip "waybar.service already disabled"
        fi
    else
        info "pikabar owns the bar on PikaOS — to use waybar instead, add 'spawn-at-startup \"waybar\"' to niri config.kdl and remove pikabar"
    fi
    return 0
}
