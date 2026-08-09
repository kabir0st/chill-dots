#!/bin/bash
# Module: prompt-starship — Starship prompt whose palette follows the
# wallpaper. chill-wallpaper splices fresh colors between the marker lines
# on every wallpaper change; the deploy below compares everything OUTSIDE
# the markers so a re-run never clobbers the live palette.

register_module prompt-starship "Starship prompt with wallpaper-driven palette" on on

PALETTE_BEGIN_MARK='# >>> chill wallust palette >>>'
PALETTE_END_MARK='# <<< chill wallust palette <<<'

mod_prompt_starship_packages() { echo starship; }

strip_wallust_palette() {
    awk -v b="$PALETTE_BEGIN_MARK" -v e="$PALETTE_END_MARK" '
        $0 == b { inblock = 1; next }
        $0 == e { inblock = 0; next }
        inblock { next }
        { lines[++n] = $0 }
        END {
            while (n > 0 && lines[n] == "") n--
            for (i = 1; i <= n; i++) print lines[i]
        }
    '
}

mod_prompt_starship_deploy() {
    local src="$SCRIPT_DIR/configs/starship/starship.toml"
    local dest="$HOME/.config/starship.toml"
    if [[ -f "$dest" ]] && [[ "$(strip_wallust_palette < "$src")" == "$(strip_wallust_palette < "$dest")" ]]; then
        skip "starship.toml already up to date (live wallust palette kept)"
        return 0
    fi
    deploy "$src" "$dest"
}
