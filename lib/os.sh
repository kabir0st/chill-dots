#!/bin/bash
# lib/os.sh — OS detection and package-manager dispatch.

CDOTS_OS=""           # the OS being installed for — set by detect_os/choose_os
CDOTS_OS_DETECTED=""  # what /etc/os-release looks like, "" when unrecognized
CDOTS_OS_PRETTY=""    # e.g. "PikaOS 4", for the OS picker

# Fills CDOTS_OS_DETECTED (and CDOTS_OS when --os was given). Never exits:
# an unrecognized system is resolved later by choose_os, interactively when
# possible so the user can just pick.
detect_os() {
    if [[ -r /etc/os-release ]]; then
        local id id_like
        id="$(. /etc/os-release && echo "${ID:-}")"
        id_like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
        CDOTS_OS_PRETTY="$(. /etc/os-release && echo "${PRETTY_NAME:-${NAME:-}}")"
        case "$id" in
            arch) CDOTS_OS_DETECTED=arch ;;
            pika) CDOTS_OS_DETECTED=pika ;;
            *)
                case " $id_like " in
                    *" arch "*)   CDOTS_OS_DETECTED=arch ;;
                    *" debian "*) CDOTS_OS_DETECTED=pika ;;
                esac ;;
        esac
    fi
    if [[ -n "$OS_OVERRIDE" ]]; then
        case "$OS_OVERRIDE" in
            arch|pika) CDOTS_OS="$OS_OVERRIDE" ;;
            *) err "Invalid --os value: $OS_OVERRIDE (expected arch or pika)"; exit 1 ;;
        esac
    fi
}

os_label() {
    case "$1" in
        arch) echo "Arch Linux" ;;
        pika) echo "PikaOS / Debian" ;;
        *)    echo "$1" ;;
    esac
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
