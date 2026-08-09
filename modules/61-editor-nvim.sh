#!/bin/bash
# Module: editor-nvim — Neovim (LazyVim) configuration.

register_module editor-nvim "Neovim (LazyVim) config" on off

mod_editor_nvim_packages() { echo neovim; }

mod_editor_nvim_deploy() {
    local f dir src
    for f in init.lua lazy-lock.json lazyvim.json stylua.toml; do
        deploy "$SCRIPT_DIR/configs/nvim/$f" "$HOME/.config/nvim/$f"
    done
    for dir in lua/config lua/plugins plugin/after; do
        for src in "$SCRIPT_DIR/configs/nvim/$dir/"*; do
            [[ -f "$src" ]] || continue
            deploy "$src" "$HOME/.config/nvim/$dir/$(basename "$src")"
        done
    done
}
