#!/bin/bash
# Wallpaper switcher with wallust auto-theming
# Usage: wallpaper.sh [path]   - set specific wallpaper
#        wallpaper.sh random   - random wallpaper from ~/Pictures/Wallpapers
#        wallpaper.sh          - pick via walker/rofi

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallust"
mkdir -p "$CACHE_DIR"

set_wallpaper() {
    local wallpaper="$1"

    if [[ ! -f "$wallpaper" ]]; then
        notify-send "Wallpaper" "File not found: $wallpaper" -u critical
        return 1
    fi

    # Update omarchy background symlink
    ln -sf "$wallpaper" "$HOME/.config/omarchy/current/background"

    # Kill swaybg if running (conflicts with swww)
    pkill -x swaybg 2>/dev/null

    # Set wallpaper with swww (smooth transition)
    if command -v swww &>/dev/null; then
        # Start swww-daemon if not running
        if ! pgrep -x swww-daemon > /dev/null; then
            swww-daemon &
            disown
            sleep 0.5
        fi
        swww img "$wallpaper" \
            --transition-type grow \
            --transition-pos "$(hyprctl cursorpos)" \
            --transition-duration 1.5 \
            --transition-fps 60 \
            --transition-bezier 0.65,0,0.35,1
    else
        # Fallback: use swaybg
        swaybg -i "$wallpaper" -m fill &
        disown
    fi

    # Generate colors with wallust
    if command -v wallust &>/dev/null; then
        wallust run "$wallpaper"

        # Apply colors live to all running kitty instances
        if [[ -f "$HOME/.config/kitty/wallust-colors.conf" ]]; then
            kitty @ set-colors --all "$HOME/.config/kitty/wallust-colors.conf" 2>/dev/null
        fi

        # Apply wallust colors to starship
        if [[ -f "$CACHE_DIR/colors-starship.toml" ]]; then
            # Merge wallust palette into starship config
            local starship_conf="$HOME/.config/starship.toml"
            if [[ -f "$starship_conf" ]]; then
                # Update palette reference
                sed -i 's/^palette = .*/palette = "wallust"/' "$starship_conf"
                # Remove existing wallust palette if present
                sed -i '/^\[palettes\.wallust\]/,/^$/d' "$starship_conf"
                # Append fresh palette
                echo "" >> "$starship_conf"
                cat "$CACHE_DIR/colors-starship.toml" >> "$starship_conf"
            fi
        fi

        # Reload mako with new colors
        if [[ -f "$HOME/.config/mako/wallust-colors.conf" ]]; then
            makoctl reload 2>/dev/null
        fi

    fi

    # Generate vibrant kitty colors from wallpaper
    vibrant-kitty-colors "$wallpaper" &

    # Save current wallpaper path
    echo "$wallpaper" > "$CACHE_DIR/current_wallpaper"
    notify-send "Wallpaper" "Theme updated from wallpaper" -i "$wallpaper" -t 3000
}

# Main logic
case "${1:-}" in
    random)
        # Pick random wallpaper
        wallpaper=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)
        if [[ -z "$wallpaper" ]]; then
            notify-send "Wallpaper" "No wallpapers found in $WALLPAPER_DIR" -u critical
            exit 1
        fi
        set_wallpaper "$wallpaper"
        ;;
    "")
        # Interactive GUI picker via waypaper
        waypaper --folder "$WALLPAPER_DIR" 2>/dev/null
        # After waypaper sets the wallpaper via swww, get the current wallpaper and apply theming
        sleep 1
        wallpaper=$(swww query 2>/dev/null | head -1 | grep -oP 'image: \K.*')
        if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
            # Update omarchy symlink
            ln -sf "$wallpaper" "$HOME/.config/omarchy/current/background"
            # Apply color theming (wallpaper already set by waypaper/swww)
            if command -v wallust &>/dev/null; then
                wallust run "$wallpaper"
                if [[ -f "$HOME/.config/kitty/wallust-colors.conf" ]]; then
                    kitty @ set-colors --all "$HOME/.config/kitty/wallust-colors.conf" 2>/dev/null
                fi
                if [[ -f "$CACHE_DIR/colors-starship.toml" ]]; then
                    local starship_conf="$HOME/.config/starship.toml"
                    if [[ -f "$starship_conf" ]]; then
                        sed -i 's/^palette = .*/palette = "wallust"/' "$starship_conf"
                        sed -i '/^\[palettes\.wallust\]/,/^$/d' "$starship_conf"
                        echo "" >> "$starship_conf"
                        cat "$CACHE_DIR/colors-starship.toml" >> "$starship_conf"
                    fi
                fi
                if [[ -f "$HOME/.config/mako/wallust-colors.conf" ]]; then
                    makoctl reload 2>/dev/null
                fi
            fi
            vibrant-kitty-colors "$wallpaper" &
            echo "$wallpaper" > "$CACHE_DIR/current_wallpaper"
            notify-send "Wallpaper" "Theme updated from wallpaper" -i "$wallpaper" -t 3000
        fi
        ;;
    *)
        # Direct path
        set_wallpaper "$1"
        ;;
esac
