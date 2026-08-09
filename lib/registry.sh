#!/bin/bash
# lib/registry.sh — module registry and runner.
#
# Each modules/*.sh file calls:
#   register_module <id> "<description>" <arch-default> <pika-default>
# where defaults are: on (selected by default), off (available, not default),
# na (hidden on that OS). It then defines plainly named functions:
#   mod_<id_with_underscores>_packages   print package names, one per line
#   mod_<id_with_underscores>_deploy     copy configs (must respect DRY_RUN)
#   mod_<id_with_underscores>_post       post-install hooks
# All functions are optional.

MODULE_IDS=()
declare -A MOD_DESC MOD_DEF_ARCH MOD_DEF_PIKA

register_module() {
    local id="$1" desc="$2" def_arch="$3" def_pika="$4"
    MODULE_IDS+=("$id")
    MOD_DESC["$id"]="$desc"
    MOD_DEF_ARCH["$id"]="$def_arch"
    MOD_DEF_PIKA["$id"]="$def_pika"
}

module_default() {
    case "$CDOTS_OS" in
        arch) echo "${MOD_DEF_ARCH[$1]}" ;;
        pika) echo "${MOD_DEF_PIKA[$1]}" ;;
    esac
}

module_available() { [[ "$(module_default "$1")" != "na" ]]; }

module_known() {
    local id
    for id in "${MODULE_IDS[@]}"; do [[ "$id" == "$1" ]] && return 0; done
    return 1
}

SELECTED_MODULES=()

module_selected() {
    local id
    for id in "${SELECTED_MODULES[@]}"; do [[ "$id" == "$1" ]] && return 0; done
    return 1
}

mod_fn() { echo "mod_${1//-/_}_$2"; }

run_module_step() {
    local fn
    fn="$(mod_fn "$1" "$2")"
    if declare -F "$fn" >/dev/null; then "$fn"; fi
    return 0
}

module_packages() {
    run_module_step "$1" packages
}

run_module() {
    local id="$1"
    echo ""
    info "── ${id} ──"
    if [[ "$SKIP_PACKAGES" != 1 ]]; then
        local pkgs=()
        mapfile -t pkgs < <(module_packages "$id")
        [[ ${#pkgs[@]} -gt 0 ]] && install_packages "${pkgs[@]}"
    fi
    run_module_step "$id" deploy
    run_module_step "$id" post
}

list_modules() {
    local id def
    echo ""
    echo "Modules on $CDOTS_OS (on = default, off = optional, na = unavailable):"
    echo ""
    for id in "${MODULE_IDS[@]}"; do
        def="$(module_default "$id")"
        printf "  %-4s %-22s %s\n" "$def" "$id" "${MOD_DESC[$id]}"
    done
    echo ""
}
