#!/bin/bash
# Module: extras-arch — the full Arch package set (dev tools, media, GUI apps,
# fonts, system pieces) from pkglist-official.txt + pkglist-aur.txt. Package
# installs use --needed, so overlap with per-module packages is a no-op.

register_module extras-arch "Full Arch package set (pkglist-official + AUR)" on na

mod_extras_arch_post() {
    if [[ "$SKIP_PACKAGES" == 1 ]]; then
        skip "extras-arch: packages skipped (--skip-packages)"
        return 0
    fi
    install_pkg_file "$SCRIPT_DIR/pkglist-official.txt"
    install_aur_file "$SCRIPT_DIR/pkglist-aur.txt"
}
