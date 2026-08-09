#!/bin/bash
# lib/os.sh — OS detection and package-manager dispatch.

CDOTS_OS=""

detect_os() {
    if [[ -n "$OS_OVERRIDE" ]]; then
        case "$OS_OVERRIDE" in
            arch|pika) CDOTS_OS="$OS_OVERRIDE" ;;
            *) err "Invalid --os value: $OS_OVERRIDE (expected arch or pika)"; exit 1 ;;
        esac
        info "OS forced via --os: $CDOTS_OS"
        return
    fi
    if [[ -r /etc/os-release ]]; then
        local id id_like
        id="$(. /etc/os-release && echo "${ID:-}")"
        id_like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
        case "$id" in
            arch) CDOTS_OS=arch ;;
            pika) CDOTS_OS=pika ;;
            *)
                case " $id_like " in
                    *" arch "*)   CDOTS_OS=arch ;;
                    *" debian "*) CDOTS_OS=pika ;;
                esac ;;
        esac
    fi
    if [[ "$CDOTS_OS" != "arch" && "$CDOTS_OS" != "pika" ]]; then
        err "Could not detect a supported OS from /etc/os-release. Re-run with --os arch or --os pika."
        exit 1
    fi
    info "Detected OS: $CDOTS_OS"
}

pkg_is_installed() {
    case "$CDOTS_OS" in
        arch) pacman -Qi "$1" &>/dev/null ;;
        pika) dpkg -s "$1" &>/dev/null ;;
    esac
}

pkg_install_one() {
    case "$CDOTS_OS" in
        arch) pkg_install_arch "$1" ;;
        pika) pkg_install_pika "$1" ;;
    esac
}

PKG_INSTALLED=0
PKG_SKIPPED=0
PKG_FAILED=0

# install_packages <name...> — one at a time so a bad name never blocks the rest
install_packages() {
    local pkg
    for pkg in "$@"; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        if pkg_is_installed "$pkg"; then
            PKG_SKIPPED=$((PKG_SKIPPED + 1))
            continue
        fi
        if [[ "$DRY_RUN" == 1 ]]; then
            dry "Would install package: $pkg"
            continue
        fi
        if pkg_install_one "$pkg"; then
            PKG_INSTALLED=$((PKG_INSTALLED + 1))
        else
            warn "Failed to install package: $pkg"
            PKG_FAILED=$((PKG_FAILED + 1))
        fi
    done
}

install_pkg_file() {
    local file="$1" pkgs=() pkg
    [[ -f "$file" ]] || { warn "Package list missing: $file"; return; }
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        pkgs+=("$pkg")
    done < "$file"
    [[ ${#pkgs[@]} -gt 0 ]] && install_packages "${pkgs[@]}"
}
