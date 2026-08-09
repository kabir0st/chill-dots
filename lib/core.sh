#!/bin/bash
# lib/core.sh — logging, deploy helpers, per-run backups, dry-run plumbing.
# Sourced by install.sh; expects SCRIPT_DIR and DRY_RUN to be set.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

# Issue tracker — collects all warnings/errors for the final summary
ISSUES=()
CHANGES=0

# Package managers log here instead of /dev/null, so a failure can be explained
# instead of just counted. Copied into the run directory at the end.
PKG_LOG="${TMPDIR:-/tmp}/chill-dots-packages-$$.log"

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ISSUES+=("WARN: $1"); }
err()   { echo -e "${RED}[ERROR]${NC} $1"; ISSUES+=("ERROR: $1"); }
skip()  { echo -e "${GRAY}[SKIP]${NC} $1"; }
dry()   { echo -e "${YELLOW}[DRY]${NC} $1"; }

# Where a replaced file's pristine copy lives inside the run directory.
backup_slot() {
    local target="$1" rel="${1#"$HOME"/}"
    [[ "$rel" == "$target" ]] && rel="${target#/}"
    printf '%s' "$RUN_DIR/files/$rel"
}

# Save the original of a file we're about to change. First write wins: a file
# touched twice in one run (config.kdl gets two includes appended) must keep
# the copy from before the run, not from between the two edits.
backup_path() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    [[ "$DRY_RUN" == 1 ]] && return 0
    run_dir_init || return 0
    local saved
    saved="$(backup_slot "$target")"
    [[ -e "$saved" || -L "$saved" ]] && return 0
    mkdir -p "$(dirname "$saved")"
    if cp -a "$target" "$saved" 2>/dev/null; then
        journal replaced "$target"
    else
        warn "Could not back up $target — leaving it untouched is safer, skipping"
        return 1
    fi
}

ensure_dir() {
    [[ "$DRY_RUN" == 1 ]] && return 0
    journal_dirs "$@"
    mkdir -p "$@"
}

# deploy <src> <dest> — copy when content differs, backing up the old file.
# Returns 0 if changed (or would change under --dry-run), 1 if up to date.
deploy() {
    local src="$1" dest="$2"
    if [[ ! -f "$src" ]]; then
        warn "Source file missing: $src"
        return 1
    fi
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
        return 1
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would update $dest"
        CHANGES=$((CHANGES + 1))
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        backup_path "$dest" || return 1
    else
        # Directory first, file second: rollback replays the journal backwards,
        # so this is the order that empties a directory before removing it.
        journal_dirs "$(dirname "$dest")"
        journal created "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    CHANGES=$((CHANGES + 1))
    return 0
}

deploy_exec() {
    local src="$1" dest="$2" rc=1
    deploy "$src" "$dest" && rc=0
    if [[ "$DRY_RUN" != 1 && -f "$dest" ]]; then
        chmod +x "$dest" 2>/dev/null || true
    fi
    return $rc
}

# deploy_rendered <src> <dest> <render_fn> — pipe src through render_fn
# (stdin -> stdout), then deploy the result with the same cmp idempotency.
deploy_rendered() {
    local src="$1" dest="$2" render_fn="$3"
    if [[ ! -f "$src" ]]; then
        warn "Source file missing: $src"
        return 1
    fi
    local tmp
    tmp="$(mktemp)" || { err "mktemp failed"; return 1; }
    if ! "$render_fn" < "$src" > "$tmp"; then
        rm -f "$tmp"
        err "Failed to render $src"
        return 1
    fi
    local rc=1
    deploy "$tmp" "$dest" && rc=0
    rm -f "$tmp"
    return $rc
}
