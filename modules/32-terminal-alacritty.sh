#!/bin/bash
# Module: terminal-alacritty — alternative terminal. The Omarchy theme import
# is stripped on PikaOS (alacritty hard-fails on missing imports).

register_module terminal-alacritty "Alacritty terminal config" on off

mod_terminal_alacritty_packages() { echo alacritty; }

render_alacritty_config() {
    if [[ "$CDOTS_OS" == pika ]]; then
        grep -v 'omarchy/current/theme/alacritty.toml'
    else
        cat
    fi
}

mod_terminal_alacritty_deploy() {
    deploy_rendered "$SCRIPT_DIR/configs/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml" render_alacritty_config
}
