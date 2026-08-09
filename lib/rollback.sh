#!/bin/bash
# lib/rollback.sh — undo a run by replaying its journal backwards.
#
# See lib/journal.sh for the record format. Rollback is deliberately
# conservative:
#   - it only touches paths the journal says this run created or replaced,
#     so files you already had (your own wallpapers, your own configs) are
#     never removed;
#   - it never uninstalls packages — removing zsh while it's your login shell
#     is a worse outcome than leaving a package behind. Rollback lists them
#     instead so you can decide;
#   - it shows exactly what it will do and asks before doing it.

# All run directories, newest first.
run_dirs() {
    local dir
    for dir in "$HOME"/.config-backup-*; do
        [[ -d "$dir" ]] && echo "$dir"
    done | sort -r
}

run_meta() {
    local dir="$1" key="$2"
    [[ -f "$dir/meta" ]] || return 1
    local line
    line="$(grep -m1 "^$key=" "$dir/meta" 2>/dev/null)" || return 1
    printf '%s' "${line#*=}"
}

run_is_rolled_back() { [[ -n "$(run_meta "$1" rolled-back || true)" ]]; }

list_runs() {
    local dir found=0 date os n_files n_journal state
    echo ""
    echo "Recorded runs (newest first):"
    echo ""
    while IFS= read -r dir; do
        [[ -n "$dir" ]] || continue
        found=1
        date="$(run_meta "$dir" date || echo "?")"
        os="$(run_meta "$dir" os || echo "?")"
        n_files=$(find "$dir/files" -type f -o -type l 2>/dev/null | wc -l)
        if [[ -f "$dir/journal.tsv" ]]; then
            n_journal=$(wc -l < "$dir/journal.tsv")
        else
            n_journal=0
            n_files=$(find "$dir" -mindepth 2 -type f -o -mindepth 2 -type l 2>/dev/null | wc -l)
        fi
        state=""
        run_is_rolled_back "$dir" && state=" ${GRAY}(already rolled back)${NC}"
        [[ -f "$dir/journal.tsv" ]] || state="$state ${GRAY}(pre-journal run — restore only)${NC}"
        echo -e "  ${BLUE}$(basename "$dir" | sed 's/^\.config-backup-//')${NC}  $date  os=$os  ${n_journal} change(s), ${n_files} file(s) saved$state"
    done < <(run_dirs)
    [[ "$found" == 0 ]] && echo "  (none — no run has changed anything yet)"
    echo ""
    echo "  Undo the most recent one:  ./install.sh --rollback"
    echo "  Undo a specific one:       ./install.sh --rollback <id>"
    echo ""
}

# Resolve the argument (empty = most recent run that hasn't been rolled back).
resolve_run_dir() {
    local want="$1" dir
    if [[ -n "$want" ]]; then
        for dir in "$HOME/.config-backup-$want" "$want"; do
            [[ -d "$dir" ]] && { printf '%s' "$dir"; return 0; }
        done
        err "No such run: $want (see ./install.sh --list-runs)"
        return 1
    fi
    while IFS= read -r dir; do
        [[ -n "$dir" ]] || continue
        run_is_rolled_back "$dir" && continue
        printf '%s' "$dir"
        return 0
    done < <(run_dirs)
    err "Nothing to roll back (see ./install.sh --list-runs)"
    return 1
}

# Guard every destructive path: only ever inside $HOME, never $HOME itself.
path_is_safe() {
    local p="$1"
    [[ "$p" == "$HOME"/?* ]] || return 1
    [[ "$p" == *".."* ]] && return 1
    return 0
}

rollback_summary() {
    local dir="$1"
    local -A counts=()
    local type rest
    while IFS=$'\t' read -r type rest; do
        [[ -z "$type" ]] && continue
        counts["$type"]=$(( ${counts["$type"]:-0} + 1 ))
    done < "$dir/journal.tsv"
    local label
    for type in replaced created created-dir created-tree unit-on unit-off chsh pipx flatpak package; do
        [[ -z "${counts[$type]:-}" ]] && continue
        case "$type" in
            replaced)     label="restore ${counts[$type]} replaced file(s) from backup" ;;
            created)      label="remove ${counts[$type]} file(s) this run created" ;;
            created-dir)  label="remove ${counts[$type]} directory(ies), only if empty" ;;
            created-tree) label="remove ${counts[$type]} downloaded/cloned directory(ies)" ;;
            unit-on)      label="disable ${counts[$type]} systemd user unit(s) this run enabled" ;;
            unit-off)     label="re-enable ${counts[$type]} systemd user unit(s) this run disabled" ;;
            chsh)         label="restore the previous login shell" ;;
            pipx)         label="uninstall ${counts[$type]} pipx package(s)" ;;
            flatpak)      label="uninstall ${counts[$type]} flatpak app(s)" ;;
            package)      label="${counts[$type]} system package(s) installed — LEFT INSTALLED" ;;
        esac
        echo "    - $label"
    done
}

# Restore a pre-journal run: put back whatever files were saved, nothing else.
rollback_legacy() {
    local dir="$1" saved rel target restored=0
    warn "This run predates the change journal — only replaced files can be restored."
    while IFS= read -r saved; do
        rel="${saved#"$dir"/}"
        target="$HOME/$rel"
        path_is_safe "$target" || { warn "Skipping unsafe path: $target"; continue; }
        if cp -a "$saved" "$target" 2>/dev/null; then
            ok "Restored $target"
            restored=$((restored + 1))
        else
            warn "Could not restore $target"
        fi
    done < <(find "$dir" -mindepth 2 \( -type f -o -type l \) 2>/dev/null)
    ok "Restored $restored file(s). Files this run created were not recorded, so they remain."
}

rollback_run() {
    local dir="$1"
    local restored=0 removed=0 dirs_removed=0 trees_removed=0 units=0 failed=0

    if [[ ! -f "$dir/journal.tsv" ]]; then
        rollback_legacy "$dir"
        printf 'rolled-back=%s\n' "$(date -Iseconds)" >> "$dir/meta"
        return 0
    fi

    # Replay backwards so later changes are undone before earlier ones.
    local lines=() line pending_dirs=()
    mapfile -t lines < "$dir/journal.tsv"
    local i type a
    for ((i = ${#lines[@]} - 1; i >= 0; i--)); do
        line="${lines[$i]}"
        [[ -z "$line" ]] && continue
        type="${line%%$'\t'*}"
        a="${line#*$'\t'}"
        [[ "$a" == "$line" ]] && a=""
        case "$type" in
            replaced)
                path_is_safe "$a" || { warn "Skipping unsafe path: $a"; continue; }
                local saved
                saved="$(RUN_DIR="$dir" backup_slot "$a")"
                if [[ ! -e "$saved" && ! -L "$saved" ]]; then
                    warn "No saved copy for $a — leaving it as is"
                    failed=$((failed + 1))
                    continue
                fi
                mkdir -p "$(dirname "$a")"
                if cp -a "$saved" "$a" 2>/dev/null; then
                    restored=$((restored + 1))
                else
                    warn "Could not restore $a"
                    failed=$((failed + 1))
                fi ;;
            created)
                path_is_safe "$a" || { warn "Skipping unsafe path: $a"; continue; }
                if [[ -e "$a" || -L "$a" ]]; then
                    rm -f "$a" && removed=$((removed + 1)) || { warn "Could not remove $a"; failed=$((failed + 1)); }
                fi ;;
            created-dir)
                # Deferred to the end: the journal doesn't guarantee that
                # everything inside a directory is recorded after it.
                pending_dirs+=("$a") ;;
            created-tree)
                path_is_safe "$a" || { warn "Skipping unsafe path: $a"; continue; }
                if [[ -d "$a" ]]; then
                    rm -rf "$a" && trees_removed=$((trees_removed + 1)) || { warn "Could not remove $a"; failed=$((failed + 1)); }
                fi ;;
            unit-on)
                systemctl --user disable --now "$a" &>/dev/null && units=$((units + 1)) || warn "Could not disable $a" ;;
            unit-off)
                systemctl --user enable "$a" &>/dev/null && units=$((units + 1)) || warn "Could not re-enable $a" ;;
            chsh)
                if [[ -x "$a" ]] && command -v chsh &>/dev/null; then
                    info "Restoring your login shell to $a (may ask for your password)..."
                    chsh -s "$a" && ok "Login shell restored to $a" || warn "chsh failed — run manually: chsh -s $a"
                fi ;;
            pipx)
                if command -v pipx &>/dev/null; then
                    pipx uninstall "$a" &>/dev/null && ok "Uninstalled pipx package $a" || warn "Could not uninstall pipx package $a"
                fi ;;
            flatpak)
                if command -v flatpak &>/dev/null; then
                    flatpak uninstall -y --user "$a" &>/dev/null && ok "Uninstalled flatpak $a" || warn "Could not uninstall flatpak $a"
                fi ;;
            package)
                : ;; # deliberately left installed
        esac
    done

    # Directories last, deepest first, and only while they're empty — a
    # directory that still holds something of yours stays exactly where it is.
    if [[ ${#pending_dirs[@]} -gt 0 ]]; then
        local candidate
        while IFS= read -r candidate; do
            [[ -n "$candidate" ]] || continue
            path_is_safe "$candidate" || continue
            rmdir "$candidate" 2>/dev/null && dirs_removed=$((dirs_removed + 1))
        done < <(printf '%s\n' "${pending_dirs[@]}" | awk -F/ '{print NF"\t"$0}' | sort -rn | cut -f2-)
    fi

    systemctl --user daemon-reload &>/dev/null || true

    echo ""
    ok "Rolled back: $restored file(s) restored, $removed removed, $dirs_removed empty dir(s), $trees_removed tree(s), $units unit change(s)"
    [[ $failed -gt 0 ]] && warn "$failed item(s) could not be undone — see the messages above"

    # grep -c prints its count AND exits 1 when there are no matches, so a
    # `|| echo 0` fallback would append a second line rather than replace it.
    local pkgs
    pkgs="$(grep -c '^package' "$dir/journal.tsv" 2>/dev/null)" || pkgs=0
    if [[ "$pkgs" -gt 0 ]]; then
        echo ""
        info "$pkgs package(s) installed by that run were left in place. To review them:"
        echo "      grep '^package' $dir/journal.tsv | cut -f2"
    fi

    printf 'rolled-back=%s\n' "$(date -Iseconds)" >> "$dir/meta"
    echo ""
    info "The run directory is kept at $dir — delete it when you're happy."
}

# Entry point for --rollback.
do_rollback() {
    local want="${1:-}" dir
    dir="$(resolve_run_dir "$want")" || exit 1

    echo ""
    echo "============================================"
    echo "  Rolling back $(basename "$dir" | sed 's/^\.config-backup-//')"
    echo "============================================"
    echo "  run date: $(run_meta "$dir" date || echo "?")"
    echo "  modules:  $(run_meta "$dir" modules || echo "?")"
    if run_is_rolled_back "$dir"; then
        warn "This run was already rolled back on $(run_meta "$dir" rolled-back)"
    fi
    echo ""
    echo "  This will:"
    if [[ -f "$dir/journal.tsv" ]]; then
        rollback_summary "$dir"
    else
        echo "    - restore every file saved in that directory (pre-journal run)"
    fi
    echo ""

    if [[ "$ROLLBACK_YES" != 1 ]] && interactive; then
        if fancy_ui; then
            tui_confirm "Roll back this run?" no || { info "Aborted — nothing was changed."; exit 0; }
        else
            local answer
            read -rp "Roll back this run? [y/N] " answer
            [[ "$answer" == y || "$answer" == Y ]] || { info "Aborted — nothing was changed."; exit 0; }
        fi
    fi

    rollback_run "$dir"
}
