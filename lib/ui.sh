#!/bin/bash
# lib/ui.sh — the interactive flow: pick the OS, pick a preset, pick modules,
# then preview exactly which packages get installed and which files change.
#
# Every prompt has a plain-text fallback (numbers typed at a prompt) for
# terminals the arrow-key UI can't drive, and is skipped entirely under
# --non-interactive or when stdin isn't a terminal.

# Can we prompt at all?
interactive() { [[ "$NON_INTERACTIVE" != 1 && -t 0 && -t 1 ]]; }

# Arrow keys available? (interactive() is the precondition)
fancy_ui() { tui_supported; }

# ============================================================================
# OS selection
# ============================================================================

require_detected_os() {
    [[ -n "$CDOTS_OS_DETECTED" ]] && return 0
    err "Could not detect a supported OS from /etc/os-release. Re-run with --os arch or --os pika."
    exit 1
}

os_detected_note() {
    if [[ -n "$CDOTS_OS_DETECTED" ]]; then
        echo "Detected ${CDOTS_OS_PRETTY:-$CDOTS_OS_DETECTED} → $(os_label "$CDOTS_OS_DETECTED")"
    else
        echo "Could not detect this system — pick the closest match"
    fi
}

# Always ask when we can; used by the install flow.
choose_os() {
    if [[ -n "$OS_OVERRIDE" ]]; then
        info "OS set by --os: $CDOTS_OS ($(os_label "$CDOTS_OS"))"
        return
    fi
    if ! interactive; then
        require_detected_os
        CDOTS_OS="$CDOTS_OS_DETECTED"
        info "Detected OS: $CDOTS_OS ($(os_label "$CDOTS_OS"))"
        return
    fi
    select_os_interactive
    if [[ -n "$CDOTS_OS_DETECTED" && "$CDOTS_OS" != "$CDOTS_OS_DETECTED" ]]; then
        warn "Installing for $CDOTS_OS on what looks like $CDOTS_OS_DETECTED — package installs may fail."
    fi
}

# Only ask when detection failed; used by --list-modules.
choose_os_auto() {
    [[ -n "$CDOTS_OS" ]] && return
    if [[ -n "$CDOTS_OS_DETECTED" ]]; then
        CDOTS_OS="$CDOTS_OS_DETECTED"
        return
    fi
    interactive || require_detected_os
    select_os_interactive
}

select_os_interactive() {
    local options=(arch pika) descs=(
        "Hyprland via Omarchy · pacman + yay"
        "niri + pikabar · pikman/apt"
    )
    local default=0 i
    [[ "$CDOTS_OS_DETECTED" == pika ]] && default=1

    if fancy_ui; then
        TUI_ITEMS=("$(os_label arch)" "$(os_label pika)")
        TUI_DESCS=("${descs[0]}" "${descs[1]}")
        if ! tui_menu "Install for which system?   ($(os_detected_note))" "$default"; then
            info "Cancelled — nothing was changed."
            exit 0
        fi
        CDOTS_OS="${options[$TUI_CHOICE]}"
    else
        echo ""
        echo "  $(os_detected_note)"
        echo ""
        for i in "${!options[@]}"; do
            printf "   %d) %-18s %s\n" "$((i + 1))" "$(os_label "${options[$i]}")" "${descs[$i]}"
        done
        local answer
        read -rp "Install for which system? [$((default + 1))] " answer
        [[ -z "$answer" ]] && answer=$((default + 1))
        case "$answer" in
            1) CDOTS_OS=arch ;;
            2) CDOTS_OS=pika ;;
            *) err "Invalid choice: $answer"; exit 1 ;;
        esac
    fi
    ok "Installing for: $(os_label "$CDOTS_OS")"
}

# ============================================================================
# Module selection
# ============================================================================

available_modules() {
    local id
    for id in "${MODULE_IDS[@]}"; do
        module_available "$id" && echo "$id"
    done
}

select_defaults() {
    local id
    for id in "${MODULE_IDS[@]}"; do
        [[ "$(module_default "$id")" == on ]] && SELECTED_MODULES+=("$id")
    done
}

select_available() {
    local id
    while IFS= read -r id; do
        SELECTED_MODULES+=("$id")
    done < <(available_modules)
}

select_from_profile() {
    local name="$1" id file
    file="$SCRIPT_DIR/profiles/$name.txt"
    [[ -f "$file" ]] || { err "Unknown profile: $name (no $file)"; exit 1; }
    while IFS= read -r id; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        module_known "$id" || { err "Profile $name references unknown module: $id"; exit 1; }
        if ! module_available "$id"; then
            warn "Module $id is not available on $CDOTS_OS — skipping"
            continue
        fi
        SELECTED_MODULES+=("$id")
    done < "$file"
}

# Fills SELECTED_MODULES from --all / --profile / --modules / the preset menu
# / the module checklist / the defaults.
resolve_selection() {
    local id
    if [[ "$SELECT_ALL" == 1 ]]; then
        select_available
        return
    fi
    if [[ -n "$PROFILE" ]]; then
        select_from_profile "$PROFILE"
        return
    fi
    if [[ -n "$MODULES_ARG" ]]; then
        local req=()
        IFS=',' read -ra req <<< "$MODULES_ARG"
        for id in "${req[@]}"; do
            module_known "$id" || { err "Unknown module: $id (see --list-modules)"; exit 1; }
            module_available "$id" || { err "Module $id is not available on $CDOTS_OS"; exit 1; }
            SELECTED_MODULES+=("$id")
        done
        return
    fi
    if ! interactive; then
        select_defaults
        info "Using the default module set for $CDOTS_OS (${#SELECTED_MODULES[@]} modules)"
        return
    fi

    select_preset_interactive
    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        info "Nothing selected — exiting."
        exit 0
    fi
}

select_preset_interactive() {
    local n_all n_default id
    n_all="$(available_modules | wc -l)"
    n_default=0
    for id in "${MODULE_IDS[@]}"; do
        [[ "$(module_default "$id")" == on ]] && n_default=$((n_default + 1))
    done

    local labels=("Recommended" "Everything" "Custom" "Configs only")
    local descs=(
        "the default set for $CDOTS_OS ($n_default modules)"
        "every module available on $CDOTS_OS ($n_all)"
        "pick modules yourself"
        "recommended set, skip all package installation"
    )
    local choice=0 i

    if fancy_ui; then
        TUI_ITEMS=("${labels[@]}")
        TUI_DESCS=("${descs[@]}")
        if ! tui_menu "What do you want to install?" 0; then
            info "Cancelled — nothing was changed."
            exit 0
        fi
        choice=$TUI_CHOICE
    else
        echo ""
        echo "What do you want to install?"
        echo ""
        for i in "${!labels[@]}"; do
            printf "   %d) %-14s %s\n" "$((i + 1))" "${labels[$i]}" "${descs[$i]}"
        done
        local answer
        read -rp "Choice [1]: " answer
        [[ -z "$answer" ]] && answer=1
        case "$answer" in
            1|2|3|4) choice=$((answer - 1)) ;;
            *) err "Invalid choice: $answer"; exit 1 ;;
        esac
    fi

    case "$choice" in
        0) select_defaults;  ok "Recommended set: ${#SELECTED_MODULES[@]} modules" ;;
        1) select_available; ok "Everything: ${#SELECTED_MODULES[@]} modules" ;;
        2) select_modules_interactive ;;
        3) SKIP_PACKAGES=1; select_defaults
           ok "Configs only: ${#SELECTED_MODULES[@]} modules, no packages will be installed" ;;
    esac
}

select_modules_interactive() {
    if fancy_ui; then
        select_modules_tui
    else
        select_modules_plain
    fi
}

select_modules_tui() {
    local id i
    TUI_ITEMS=()
    TUI_DESCS=()
    TUI_STATES=()
    TUI_DEFAULTS=()
    while IFS= read -r id; do
        TUI_ITEMS+=("$id")
        TUI_DESCS+=("${MOD_DESC[$id]}")
        if [[ "$(module_default "$id")" == on ]]; then
            TUI_STATES+=(1); TUI_DEFAULTS+=(1)
        else
            TUI_STATES+=(0); TUI_DEFAULTS+=(0)
        fi
    done < <(available_modules)

    if ! tui_checklist "Select components for $(os_label "$CDOTS_OS")"; then
        info "Cancelled — nothing was changed."
        exit 0
    fi
    for i in "${!TUI_ITEMS[@]}"; do
        [[ "${TUI_STATES[$i]}" == 1 ]] && SELECTED_MODULES+=("${TUI_ITEMS[$i]}")
    done
    ok "Selected ${#SELECTED_MODULES[@]} module(s)"
}

# Fallback picker for terminals the arrow-key UI can't drive.
select_modules_plain() {
    local avail=() states=() i id answer
    while IFS= read -r id; do
        avail+=("$id")
        if [[ "$(module_default "$id")" == on ]]; then states+=(1); else states+=(0); fi
    done < <(available_modules)
    echo ""
    echo "Select components for $(os_label "$CDOTS_OS"):"
    while true; do
        echo ""
        for i in "${!avail[@]}"; do
            local mark=" "
            [[ "${states[$i]}" == 1 ]] && mark="x"
            printf "  %2d) [%s] %-22s %s\n" "$((i + 1))" "$mark" "${avail[$i]}" "${MOD_DESC[${avail[$i]}]}"
        done
        echo ""
        read -rp "Toggle by number, 'a'=all, 'n'=none, Enter=done: " answer
        case "$answer" in
            "") break ;;
            a)  for i in "${!states[@]}"; do states[$i]=1; done ;;
            n)  for i in "${!states[@]}"; do states[$i]=0; done ;;
            *[!0-9]*) echo "  Not a number." ;;
            *)
                i=$((answer - 1))
                if [[ $i -ge 0 && $i -lt ${#avail[@]} ]]; then
                    states[$i]=$((1 - states[$i]))
                else
                    echo "  Out of range."
                fi ;;
        esac
    done
    for i in "${!avail[@]}"; do
        [[ "${states[$i]}" == 1 ]] && SELECTED_MODULES+=("${avail[$i]}")
    done
}

# ============================================================================
# Preview + confirmation
# ============================================================================

# Show, per selected module, missing packages and files that would change.
# File changes come from a dry-run pass of the module's deploy step inside a
# subshell (process substitution), so nothing leaks into the real run.
preview_selection() {
    echo ""
    info "Planned changes for: ${SELECTED_MODULES[*]}"
    local id pkg line
    for id in "${SELECTED_MODULES[@]}"; do
        local missing=()
        if [[ "$SKIP_PACKAGES" != 1 ]]; then
            while IFS= read -r pkg; do
                [[ -z "$pkg" || "$pkg" == \#* ]] && continue
                pkg_is_installed "$pkg" || missing+=("$pkg")
            done < <(module_packages "$id")
        fi
        local file_lines=""
        file_lines="$(DRY_RUN=1 run_module_step "$id" deploy 2>/dev/null | grep -F '[DRY]' || true)"
        if [[ ${#missing[@]} -eq 0 && -z "$file_lines" ]]; then
            continue
        fi
        echo ""
        echo -e "  ${BLUE}${id}${NC}"
        [[ ${#missing[@]} -gt 0 ]] && echo "    install: ${missing[*]}"
        if [[ -n "$file_lines" ]]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && echo "    $line"
            done <<< "$file_lines"
        fi
    done
    echo ""
    [[ "$SKIP_PACKAGES" == 1 ]] && info "Package installation is off (--skip-packages / configs only)."
    info "Files being replaced are backed up to ~/.config-backup-<timestamp>/ first."
}

confirm_proceed() {
    [[ "$DRY_RUN" == 1 ]] && return 0
    interactive || return 0
    if fancy_ui; then
        tui_confirm "Proceed with installation?" no || { info "Aborted."; exit 0; }
    else
        local answer
        read -rp "Proceed with installation? [y/N] " answer
        [[ "$answer" == y || "$answer" == Y ]] || { info "Aborted."; exit 0; }
    fi
}
