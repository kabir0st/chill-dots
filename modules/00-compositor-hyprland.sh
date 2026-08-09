#!/bin/bash
# Module: compositor-hyprland — Hyprland configs + Omarchy hooks (Arch/Omarchy only).
# Hyprland itself is provided by the Omarchy base install.

register_module compositor-hyprland "Hyprland configs (animations, blur, bindings) + Omarchy hooks" on na

mod_compositor_hyprland_deploy() {
    local f
    for f in hyprland.conf looknfeel.conf bindings.conf monitors.conf input.conf autostart.conf hyprsunset.conf xdph.conf; do
        deploy "$SCRIPT_DIR/configs/hypr/$f" "$HOME/.config/hypr/$f"
    done
    deploy_exec "$SCRIPT_DIR/configs/omarchy/hooks/theme-set" "$HOME/.config/omarchy/hooks/theme-set"
    deploy "$SCRIPT_DIR/configs/omarchy/extensions/menu.sh" "$HOME/.config/omarchy/extensions/menu.sh"
}
