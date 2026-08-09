#!/bin/bash
# Module: wallpapers — the curated wallpaper collection.

register_module wallpapers "Curated wallpapers → ~/Pictures/Wallpapers" on on

mod_wallpapers_deploy() {
    ensure_dir "$HOME/Pictures/Wallpapers"
    local copied=0 skipped=0 failed=0 src filename dest
    while IFS= read -r -d '' src; do
        filename="$(basename "$src")"
        dest="$HOME/Pictures/Wallpapers/$filename"
        if [[ -f "$dest" ]]; then
            skipped=$((skipped + 1))
        elif [[ "$DRY_RUN" == 1 ]]; then
            copied=$((copied + 1))
        elif cp -- "$src" "$dest"; then
            copied=$((copied + 1))
        else
            warn "Failed to copy wallpaper: $filename"
            failed=$((failed + 1))
        fi
    done < <(find "$SCRIPT_DIR/wallpapers" -maxdepth 1 -type f -print0 2>/dev/null)

    if [[ "$DRY_RUN" == 1 ]]; then
        [[ $copied -gt 0 ]] && dry "Would copy $copied wallpapers to ~/Pictures/Wallpapers/"
    elif [[ $copied -eq 0 && $failed -eq 0 ]]; then
        skip "All $skipped wallpapers already in ~/Pictures/Wallpapers/"
    else
        ok "Wallpapers: $copied copied, $skipped already existed, $failed failed"
    fi
}
