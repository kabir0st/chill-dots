#!/bin/bash
# Module: terminal-ghostty — alternative terminal. Its omarchy/wallust
# includes are already optional (`?` prefix), so one config works on both OSes.

register_module terminal-ghostty "Ghostty terminal config + wallust colors" on off

mod_terminal_ghostty_packages() { echo ghostty; }

mod_terminal_ghostty_deploy() {
    deploy "$SCRIPT_DIR/configs/ghostty/config" "$HOME/.config/ghostty/config"
}
