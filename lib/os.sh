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
SUDO_PRIMED=0
SUDO_KEEPALIVE_PID=""

# Ask for the sudo password once, up front and visibly. Package managers get
# their output redirected to $PKG_LOG, so a password prompt appearing in the
# middle of an install is easy to miss — and every package then "fails".
prime_sudo() {
    [[ "$SUDO_PRIMED" == 1 ]] && return 0
    [[ "$DRY_RUN" == 1 ]] && return 0
    command -v sudo &>/dev/null || { SUDO_PRIMED=1; return 0; }
    if sudo -n true 2>/dev/null; then
        SUDO_PRIMED=1
        return 0
    fi
    echo ""
    info "Installing packages needs sudo — enter your password once:"
    if ! sudo -v; then
        err "sudo authentication failed — skipping package installation"
        return 1
    fi
    SUDO_PRIMED=1
    # Long installs outlive the default 15-minute sudo timestamp.
    ( while sleep 60; do sudo -n true 2>/dev/null || break; kill -0 "$$" 2>/dev/null || break; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'stop_sudo_keepalive' EXIT
    return 0
}

stop_sudo_keepalive() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] || return 0
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    SUDO_KEEPALIVE_PID=""
}

# install_packages <name...> — one transaction where the OS supports it, then
# one at a time so a single bad name never blocks the rest.
install_packages() {
    local pkg missing=()
    for pkg in "$@"; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        if pkg_is_installed "$pkg"; then
            PKG_SKIPPED=$((PKG_SKIPPED + 1))
        else
            missing+=("$pkg")
        fi
    done
    [[ ${#missing[@]} -eq 0 ]] && return 0

    if [[ "$DRY_RUN" == 1 ]]; then
        for pkg in "${missing[@]}"; do dry "Would install package: $pkg"; done
        return 0
    fi

    if ! prime_sudo; then
        for pkg in "${missing[@]}"; do
            warn "Skipped package (no sudo): $pkg"
            PKG_FAILED=$((PKG_FAILED + 1))
        done
        return 0
    fi

    local many_fn="pkg_install_many_$CDOTS_OS"
    if declare -F "$many_fn" >/dev/null; then
        info "Installing ${#missing[@]} package(s): ${missing[*]}"
        if "$many_fn" "${missing[@]}"; then
            pkg_tally "${missing[@]}"
            return 0
        fi
        warn "Installing them together failed — retrying one at a time to find the culprit"
    fi

    for pkg in "${missing[@]}"; do
        if pkg_install_one "$pkg" && pkg_is_installed "$pkg"; then
            PKG_INSTALLED=$((PKG_INSTALLED + 1))
            journal package "$pkg"
            ok "Installed $pkg"
        else
            warn "Failed to install package: $pkg (details: $PKG_LOG)"
            PKG_FAILED=$((PKG_FAILED + 1))
        fi
    done
}

# Attribute a batch install per package, so a partial success is reported honestly.
pkg_tally() {
    local pkg
    for pkg in "$@"; do
        if pkg_is_installed "$pkg"; then
            PKG_INSTALLED=$((PKG_INSTALLED + 1))
            journal package "$pkg"
        else
            warn "Package reported success but is not installed: $pkg (details: $PKG_LOG)"
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
