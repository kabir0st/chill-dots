#!/bin/bash
# Module: terminal-kitty — kitty with the chill look (JetBrainsMono Nerd Font,
# opacity, cursor trail, powerline tabs) + live wallust colors.

register_module terminal-kitty "Kitty terminal: fonts, cursor trail, tabs + live wallust colors" on on

mod_terminal_kitty_packages() {
    case "$CDOTS_OS" in
        arch) printf '%s\n' kitty ttf-jetbrains-mono-nerd noto-fonts-emoji ;;
        pika) printf '%s\n' kitty fonts-noto-color-emoji ;;
    esac
}

mod_terminal_kitty_deploy() {
    deploy "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    deploy "$SCRIPT_DIR/configs/kitty/theme.$CDOTS_OS.conf" "$HOME/.config/kitty/theme.conf"
    # Empty placeholder until wallust renders real colors — kitty logs an
    # error for missing includes otherwise.
    if [[ ! -f "$HOME/.config/kitty/wallust-colors.conf" && "$DRY_RUN" != 1 ]]; then
        journal_dirs "$HOME/.config/kitty"
        mkdir -p "$HOME/.config/kitty"
        journal created "$HOME/.config/kitty/wallust-colors.conf"
        touch "$HOME/.config/kitty/wallust-colors.conf"
    fi
}

mod_terminal_kitty_post() {
    if [[ "$CDOTS_OS" == pika ]]; then
        pika_install_nerd_font
    fi
    return 0
}
