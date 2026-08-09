#!/bin/bash
# Module: shell-zsh — zsh + Oh My Zsh + plugins + the chill .zshrc
# (autosuggestions, syntax highlighting, substring search, eza/fzf/zoxide).

register_module shell-zsh "Zsh + Oh My Zsh + plugins, aliases, fzf/zoxide/eza (sets default shell)" on on

mod_shell_zsh_packages() {
    case "$CDOTS_OS" in
        arch) printf '%s\n' zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf zoxide eza bat fd git ;;
        pika) printf '%s\n' zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat fd-find git ;;
    esac
}

mod_shell_zsh_deploy() {
    deploy "$SCRIPT_DIR/shell/.zshrc" "$HOME/.zshrc"
}

mod_shell_zsh_post() {
    if [[ "$DRY_RUN" == 1 ]]; then
        [[ -d "$HOME/.oh-my-zsh" ]] || dry "Would install Oh My Zsh + custom plugins"
        [[ "$SHELL" == *zsh* ]] || dry "Would set zsh as the default shell"
        return 0
    fi

    # --keep-zshrc matters: the module deploys .zshrc first, and the OMZ
    # installer would otherwise replace it with its own template.
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        info "Installing Oh My Zsh..."
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc; then
            ok "Oh My Zsh installed"
        else
            err "Failed to install Oh My Zsh"
        fi
    else
        skip "Oh My Zsh already installed"
    fi

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local plugin url
    for plugin in zsh-history-substring-search you-should-use; do
        case "$plugin" in
            zsh-history-substring-search) url="https://github.com/zsh-users/zsh-history-substring-search" ;;
            you-should-use)               url="https://github.com/MichaelAquilina/zsh-you-should-use" ;;
        esac
        if [[ -d "$zsh_custom/plugins/$plugin" ]]; then
            skip "$plugin already installed"
        elif git clone "$url" "$zsh_custom/plugins/$plugin" &>/dev/null; then
            ok "$plugin installed"
        else
            err "Failed to clone $plugin"
        fi
    done

    set_default_shell_zsh
}

set_default_shell_zsh() {
    if [[ "$SHELL" == *zsh* ]]; then
        skip "zsh already the default shell"
        return 0
    fi
    local zsh_bin
    zsh_bin="$(command -v zsh || true)"
    if [[ -z "$zsh_bin" ]]; then
        warn "zsh not installed — cannot set default shell"
        return 0
    fi
    if ! grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
        warn "$zsh_bin is not listed in /etc/shells — run manually: chsh -s $zsh_bin"
        return 0
    fi
    if [[ "$NON_INTERACTIVE" == 1 || ! -t 0 ]]; then
        warn "Skipping chsh in non-interactive mode — run manually: chsh -s $zsh_bin"
        return 0
    fi
    info "Setting zsh as the default shell (may ask for your password)..."
    if chsh -s "$zsh_bin"; then
        ok "Default shell set to zsh (takes effect at next login)"
    else
        warn "chsh failed — run manually: chsh -s $zsh_bin"
    fi
}
