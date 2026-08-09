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

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ISSUES+=("WARN: $1"); }
err()   { echo -e "${RED}[ERROR]${NC} $1"; ISSUES+=("ERROR: $1"); }
skip()  { echo -e "${GRAY}[SKIP]${NC} $1"; }
dry()   { echo -e "${YELLOW}[DRY]${NC} $1"; }

# Per-run backup dir, created lazily the first time an existing file is
# about to be replaced. Every run that changes files gets its own backup.
BACKUP_DIR=""

backup_path() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    [[ "$DRY_RUN" == 1 ]] && return 0
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        info "Backing up replaced files to $BACKUP_DIR"
    fi
    local rel="${target#"$HOME"/}"
    [[ "$rel" == "$target" ]] && rel="${target#/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$target" "$BACKUP_DIR/$rel" 2>/dev/null || true
}

ensure_dir() {
    [[ "$DRY_RUN" == 1 ]] && return 0
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
    backup_path "$dest"
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
