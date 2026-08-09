#!/bin/bash
# lib/journal.sh — the per-run change journal that makes rollback possible.
#
# Backing up replaced files is not enough to undo a run: most of what the
# installer does is *create* things that were never there (config files,
# wallpapers, systemd units, cloned plugin repos). So every run that writes
# anything records what it did, in order, in its own run directory:
#
#   ~/.config-backup-<timestamp>/
#     meta          key=value lines (date, os, modules, rolled-back marker)
#     journal.tsv   one tab-separated record per change, in the order it happened
#     files/        pristine copies of every file we replaced
#
# Record types:
#   replaced      <path>        original lives under files/<path relative to $HOME>
#   created       <path>        file we made that did not exist before
#   created-dir   <path>        directory we made (rollback removes it only if empty)
#   created-tree  <path>        directory tree we cloned/extracted (rollback rm -rf)
#   unit-on       <user unit>   we ran systemctl --user enable
#   unit-off      <user unit>   we ran systemctl --user disable
#   chsh          <old shell>   we changed the login shell
#   pipx          <package>     we installed a pipx package
#   flatpak       <app id>      we installed a flatpak application
#   package       <name>        a package we installed (left alone by rollback)
#
# Reading the journal back is lib/rollback.sh.

RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR=""

# Create the run directory the first time something is actually recorded, so a
# no-op run leaves nothing behind. Returns 1 when there's nothing to record to
# (dry runs), which every caller treats as "skip recording".
run_dir_init() {
    [[ "$DRY_RUN" == 1 ]] && return 1
    [[ -n "$RUN_DIR" ]] && return 0
    local dir="$HOME/.config-backup-$RUN_STAMP"
    if ! mkdir -p "$dir/files" 2>/dev/null; then
        warn "Could not create the run directory $dir — this run cannot be rolled back"
        return 1
    fi
    RUN_DIR="$dir"
    {
        echo "date=$(date -Iseconds)"
        echo "os=$CDOTS_OS"
        echo "modules=${SELECTED_MODULES[*]}"
    } > "$RUN_DIR/meta"
    info "Recording this run in $RUN_DIR (undo with ./install.sh --rollback)"
    return 0
}

# journal <type> <field>... — append one record.
journal() {
    [[ "$DRY_RUN" == 1 ]] && return 0
    run_dir_init || return 0
    local line="$1" field
    shift
    for field in "$@"; do
        # Tabs and newlines would corrupt the record; no real config path has
        # them, so refuse rather than write something rollback can't parse.
        if [[ "$field" == *$'\t'* || "$field" == *$'\n'* ]]; then
            warn "Not journalling a path containing a tab or newline: $field"
            return 0
        fi
        line+=$'\t'"$field"
    done
    printf '%s\n' "$line" >> "$RUN_DIR/journal.tsv"
}

# journal_created <path> — record a file we are about to create, but only if
# it really is new (callers are not always sure).
journal_created() {
    [[ -e "$1" || -L "$1" ]] && return 0
    journal created "$1"
}

# journal_dirs <path>... — record directories that do not exist yet.
journal_dirs() {
    local dir
    for dir in "$@"; do
        [[ -d "$dir" ]] || journal created-dir "$dir"
    done
}

# For things written by an external tool (wallust rendering its templates):
# note which paths are missing beforehand, then record the ones that appeared.
JOURNAL_WATCH=()

journal_watch_begin() {
    JOURNAL_WATCH=()
    local path
    for path in "$@"; do
        [[ -e "$path" || -L "$path" ]] || JOURNAL_WATCH+=("$path")
    done
}

journal_watch_end() {
    local path
    for path in "${JOURNAL_WATCH[@]}"; do
        [[ -e "$path" || -L "$path" ]] && journal created "$path"
    done
    JOURNAL_WATCH=()
}
