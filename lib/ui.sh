#!/bin/bash
# lib/ui.sh — module selection (gum with a plain-bash fallback) and the
# pre-flight preview showing what would be installed and replaced.

have_gum() { command -v gum &>/dev/null; }

# Fills SELECTED_MODULES from --all / --profile / --modules / defaults /
# the interactive picker.
resolve_selection() {
    local id
    if [[ "$SELECT_ALL" == 1 ]]; then
        for id in "${MODULE_IDS[@]}"; do
            module_available "$id" && SELECTED_MODULES+=("$id")
        done
        return
    fi
    if [[ -n "$PROFILE" ]]; then
        local file="$SCRIPT_DIR/profiles/$PROFILE.txt"
        [[ -f "$file" ]] || { err "Unknown profile: $PROFILE (no $file)"; exit 1; }
        while IFS= read -r id; do
            [[ -z "$id" || "$id" == \#* ]] && continue
            module_known "$id" || { err "Profile $PROFILE references unknown module: $id"; exit 1; }
            if ! module_available "$id"; then
                warn "Module $id is not available on $CDOTS_OS — skipping"
                continue
            fi
            SELECTED_MODULES+=("$id")
        done < "$file"
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
    if [[ "$NON_INTERACTIVE" == 1 || ! -t 0 ]]; then
        for id in "${MODULE_IDS[@]}"; do
            [[ "$(module_default "$id")" == on ]] && SELECTED_MODULES+=("$id")
        done
        info "Using the default module set for $CDOTS_OS (${#SELECTED_MODULES[@]} modules)"
        return
    fi
    select_modules_interactive
    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        info "Nothing selected — exiting."
        exit 0
    fi
}

select_modules_interactive() {
    local id
    if have_gum; then
        local items=() preselected=()
        for id in "${MODULE_IDS[@]}"; do
            module_available "$id" || continue
            items+=("$id")
            [[ "$(module_default "$id")" == on ]] && preselected+=("$id")
        done
        local sel_arg chosen
        sel_arg=$(IFS=,; echo "${preselected[*]}")
        if ! chosen="$(gum choose --no-limit --height 22 --selected "$sel_arg" \
            --header "Select components for $CDOTS_OS (space = toggle, enter = confirm)" \
            "${items[@]}")"; then
            info "Selection cancelled — exiting."
            exit 0
        fi
        while IFS= read -r id; do
            [[ -n "$id" ]] && SELECTED_MODULES+=("$id")
        done <<< "$chosen"
    else
        select_modules_plain
    fi
}

select_modules_plain() {
    local avail=() states=() i id answer
    for id in "${MODULE_IDS[@]}"; do
        module_available "$id" || continue
        avail+=("$id")
        if [[ "$(module_default "$id")" == on ]]; then states+=(1); else states+=(0); fi
    done
    echo ""
    echo "Select components to install on $CDOTS_OS:"
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
    info "Files being replaced are backed up to ~/.config-backup-<timestamp>/ first."
}

confirm_proceed() {
    [[ "$NON_INTERACTIVE" == 1 || ! -t 0 || "$DRY_RUN" == 1 ]] && return 0
    if have_gum; then
        gum confirm "Proceed with installation?" || { info "Aborted."; exit 0; }
    else
        local answer
        read -rp "Proceed with installation? [y/N] " answer
        [[ "$answer" == y || "$answer" == Y ]] || { info "Aborted."; exit 0; }
    fi
}
