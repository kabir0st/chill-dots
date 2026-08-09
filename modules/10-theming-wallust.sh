#!/bin/bash
# Module: theming-wallust — the color engine. Wallust extracts a 16-color
# palette from the wallpaper and renders per-app templates; chill-wallpaper
# drives it and reloads running apps.

register_module theming-wallust "Wallust auto-theming engine + templates + chill-wallpaper" on on

mod_theming_wallust_packages() {
    echo wallust
}

mod_theming_wallust_deploy() {
    deploy "$SCRIPT_DIR/configs/wallust/wallust.toml" "$HOME/.config/wallust/wallust.toml"
    local src
    for src in "$SCRIPT_DIR/configs/wallust/templates/"*; do
        [[ -f "$src" ]] || continue
        deploy "$src" "$HOME/.config/wallust/templates/$(basename "$src")"
    done
    deploy_exec "$SCRIPT_DIR/bin/chill-wallpaper" "$HOME/.local/bin/chill-wallpaper"
    # Pre-create every template target dir so `wallust run` never fails a write
    ensure_dir "$HOME/.config/hypr/wallust" "$HOME/.config/waybar/wallust" \
        "$HOME/.config/kitty" "$HOME/.config/mako" "$HOME/.config/niri" \
        "$HOME/.config/ghostty" "$HOME/.cache/wallust"
}
