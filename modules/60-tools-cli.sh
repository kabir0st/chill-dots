#!/bin/bash
# Module: tools-cli — btop, tmux, lazygit, fastfetch, gum configs + packages.

register_module tools-cli "CLI tools: btop, tmux, lazygit, fastfetch, gum" on off

mod_tools_cli_packages() {
    case "$CDOTS_OS" in
        arch) printf '%s\n' btop tmux lazygit lazydocker fastfetch gum ;;
        pika) printf '%s\n' btop tmux lazygit fastfetch gum ;;
    esac
}

mod_tools_cli_deploy() {
    deploy "$SCRIPT_DIR/configs/btop/btop.conf" "$HOME/.config/btop/btop.conf"
    deploy "$SCRIPT_DIR/configs/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    if [[ "$CDOTS_OS" == pika ]]; then
        # The Arch config shells out to omarchy-* commands for several rows
        deploy "$SCRIPT_DIR/configs/fastfetch/config.pika.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    else
        deploy "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    fi
    deploy "$SCRIPT_DIR/configs/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt"
}
