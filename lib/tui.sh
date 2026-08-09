#!/bin/bash
# lib/tui.sh — dependency-free arrow-key menus.
#
# No gum, no whiptail, no dialog: just ANSI escapes and `read`, so the same
# interface works on a fresh Arch box and on PikaOS without installing
# anything first.
#
# Callers fill the TUI_* globals, then call an entry point:
#
#   TUI_ITEMS=(label ...)  TUI_DESCS=(text ...)
#   tui_menu "Header" <default_index>   -> TUI_CHOICE=<index>; returns 1 if cancelled
#
#   TUI_ITEMS=(id ...)  TUI_DESCS=(text ...)
#   TUI_STATES=(1 0 ...)  TUI_DEFAULTS=(1 0 ...)
#   tui_checklist "Header"              -> updates TUI_STATES; returns 1 if cancelled
#
# Check tui_supported before calling; the caller owns the fallback.

TUI_ITEMS=()
TUI_DESCS=()
TUI_STATES=()
TUI_DEFAULTS=()
TUI_CHOICE=-1

# Real escape bytes so frames can be printed with %s (core.sh's colors are
# literal backslash sequences meant for `echo -e`).
_C_RESET=$'\e[0m'
_C_DIM=$'\e[0;90m'
_C_BLUE=$'\e[0;34m'
_C_CYAN=$'\e[1;36m'
_C_GREEN=$'\e[0;32m'

tui_supported() {
    [[ -t 0 && -t 1 ]] || return 1
    case "${TERM:-dumb}" in dumb | "") return 1 ;; esac
    command -v tput &>/dev/null || return 1
    return 0
}

# Sizes fall back to 24x80 when the terminal reports nothing usable
# (0x0 happens under `script`, cron-ish ptys, and some SSH clients).
_tui_rows() {
    local n
    n="$(tput lines 2>/dev/null)" || n=""
    [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 10)) || n=24
    echo "$n"
}

_tui_cols() {
    local n
    n="$(tput cols 2>/dev/null)" || n=""
    [[ "$n" =~ ^[0-9]+$ ]] && ((n >= 40)) || n=80
    echo "$n"
}

_tui_drawn=0

_tui_begin() {
    printf '\e[?25l'
    _tui_drawn=0
    trap '_tui_end; exit 130' INT
}

_tui_end() {
    printf '\e[?25h'
    trap - INT
}

# Emit one frame line, clearing whatever the previous frame left there.
_tui_line() {
    printf '\e[2K%s\n' "$1"
    _tui_drawn=$((_tui_drawn + 1))
}

# Jump back to the top of the frame so the next one overwrites it in place
# (no clear-screen, so scrollback survives).
_tui_rewind() {
    [[ $_tui_drawn -gt 0 ]] && printf '\e[%dA' "$_tui_drawn"
    _tui_drawn=0
    return 0
}

# Wipe the frame and leave the cursor where it started, so the caller can
# print a one-line summary of what was picked instead of a stale menu.
_tui_erase() {
    local n=$_tui_drawn i
    ((n == 0)) && return 0
    printf '\e[%dA' "$n"
    for ((i = 0; i < n; i++)); do printf '\e[2K\n'; done
    printf '\e[%dA' "$n"
    _tui_drawn=0
    return 0
}

# Truncate to a character budget, marking cuts with an ellipsis.
_tui_fit() {
    local s="$1" max="$2"
    ((max < 1)) && max=1
    if ((${#s} <= max)); then
        printf '%s' "$s"
    else
        printf '%s…' "${s:0:max - 1}"
    fi
}

_tui_rule() {
    local width="$1" out=""
    while ((${#out} < width)); do out+="─"; done
    printf '%s' "$out"
}

# _tui_frame <header> <visible> <off> <cur> <show_boxes> <hint>
# Draws a constant number of lines: blank, header, rule, N rows, rule, hint.
_tui_frame() {
    local header="$1" visible="$2" off="$3" cur="$4" show_boxes="$5" hint="$6"
    local n=${#TUI_ITEMS[@]} cols rule_width i idx prefix rest row

    cols="$(_tui_cols)"
    rule_width=$((cols - 4))
    ((rule_width > 74)) && rule_width=74
    ((rule_width < 10)) && rule_width=10

    local top_rule bottom_rule
    top_rule="$(_tui_rule "$rule_width")"
    bottom_rule="$top_rule"
    ((off > 0)) && top_rule="${top_rule:0:rule_width - 8}  ↑ more"
    ((off + visible < n)) && bottom_rule="${bottom_rule:0:rule_width - 8}  ↓ more"

    _tui_line ""
    _tui_line "  ${_C_BLUE}${header}${_C_RESET}"
    _tui_line "  ${_C_DIM}${top_rule}${_C_RESET}"

    for ((i = 0; i < visible; i++)); do
        idx=$((off + i))
        if ((idx >= n)); then
            _tui_line ""
            continue
        fi
        if ((idx == cur)); then prefix="  ${_C_CYAN}▸${_C_RESET} "; else prefix="    "; fi
        if [[ "$show_boxes" == 1 ]]; then
            if [[ "${TUI_STATES[$idx]}" == 1 ]]; then
                prefix+="${_C_GREEN}[x]${_C_RESET} "
            else
                prefix+="${_C_DIM}[ ]${_C_RESET} "
            fi
        fi
        rest="$(printf '%-22s %s' "${TUI_ITEMS[$idx]}" "${TUI_DESCS[$idx]:-}")"
        # 4 cursor cells + 4 checkbox cells; leave a column so nothing wraps.
        local budget=$((cols - 9))
        [[ "$show_boxes" == 1 ]] || budget=$((cols - 5))
        rest="$(_tui_fit "$rest" "$budget")"
        if ((idx == cur)); then row="${prefix}${_C_CYAN}${rest}${_C_RESET}"; else row="${prefix}${rest}"; fi
        _tui_line "$row"
    done

    _tui_line "  ${_C_DIM}${bottom_rule}${_C_RESET}"
    _tui_line "  ${_C_DIM}$(_tui_fit "$hint" $((cols - 3)))${_C_RESET}"
}

# Read one keypress, normalized to a word (up/down/enter/space/cancel/char:X).
_tui_key() {
    local k rest extra
    IFS= read -rsn1 k || { echo cancel; return; }
    if [[ -z "$k" ]]; then echo enter; return; fi
    if [[ "$k" == $'\e' ]]; then
        IFS= read -rsn2 -t 0.2 rest || rest=""
        case "$rest" in
            '[A') echo up ;;
            '[B') echo down ;;
            '[C') echo right ;;
            '[D') echo left ;;
            '[H') echo home ;;
            '[F') echo end ;;
            '[5') IFS= read -rsn1 -t 0.2 extra || extra=""; echo pgup ;;
            '[6') IFS= read -rsn1 -t 0.2 extra || extra=""; echo pgdn ;;
            '') echo cancel ;;
            *) echo unknown ;;
        esac
        return
    fi
    case "$k" in
        ' ') echo space ;;
        *) printf 'char:%s\n' "$k" ;;
    esac
}

# How many list rows fit: total rows minus the 6 frame lines and a little slack.
_tui_visible() {
    local n="$1" rows visible
    rows="$(_tui_rows)"
    visible=$((rows - 8))
    ((visible < 3)) && visible=3
    ((visible > n)) && visible=$n
    echo "$visible"
}

# Keep the cursor inside the viewport.
_tui_scroll() {
    local cur="$1" off="$2" visible="$3"
    ((cur < off)) && off=$cur
    ((cur >= off + visible)) && off=$((cur - visible + 1))
    ((off < 0)) && off=0
    echo "$off"
}

# tui_menu <header> [default_index] -> TUI_CHOICE
tui_menu() {
    local header="$1" cur="${2:-0}"
    local n=${#TUI_ITEMS[@]}
    ((n > 0)) || return 1
    ((cur < 0 || cur >= n)) && cur=0
    local visible off key digit
    visible="$(_tui_visible "$n")"
    off="$(_tui_scroll "$cur" 0 "$visible")"
    TUI_CHOICE=-1

    _tui_begin
    while true; do
        _tui_rewind
        _tui_frame "$header" "$visible" "$off" "$cur" 0 \
            "↑↓ move · 1-9 jump · enter select · q cancel"
        key="$(_tui_key)"
        case "$key" in
            up | char:k) ((cur > 0)) && cur=$((cur - 1)) ;;
            down | char:j) ((cur < n - 1)) && cur=$((cur + 1)) ;;
            home | pgup) cur=0 ;;
            end | pgdn) cur=$((n - 1)) ;;
            enter) TUI_CHOICE=$cur; break ;;
            cancel | char:q | char:Q) TUI_CHOICE=-1; break ;;
            char:[1-9])
                digit="${key#char:}"
                ((digit <= n)) && cur=$((digit - 1)) ;;
        esac
        off="$(_tui_scroll "$cur" "$off" "$visible")"
    done
    _tui_erase
    _tui_end
    [[ $TUI_CHOICE -ge 0 ]]
}

# tui_checklist <header> -> updates TUI_STATES in place
tui_checklist() {
    local header="$1"
    local n=${#TUI_ITEMS[@]}
    ((n > 0)) || return 1
    local visible off cur=0 key i rc=0
    visible="$(_tui_visible "$n")"
    off=0

    _tui_begin
    while true; do
        _tui_rewind
        _tui_frame "$header" "$visible" "$off" "$cur" 1 \
            "↑↓ move · space toggle · a all · n none · d defaults · enter ok · q cancel"
        key="$(_tui_key)"
        case "$key" in
            up | char:k) ((cur > 0)) && cur=$((cur - 1)) ;;
            down | char:j) ((cur < n - 1)) && cur=$((cur + 1)) ;;
            home) cur=0 ;;
            end) cur=$((n - 1)) ;;
            pgup) cur=$((cur - visible)); ((cur < 0)) && cur=0 ;;
            pgdn) cur=$((cur + visible)); ((cur > n - 1)) && cur=$((n - 1)) ;;
            space | right | char:x)
                TUI_STATES[cur]=$((1 - TUI_STATES[cur])) ;;
            char:a | char:A) for ((i = 0; i < n; i++)); do TUI_STATES[i]=1; done ;;
            char:n | char:N) for ((i = 0; i < n; i++)); do TUI_STATES[i]=0; done ;;
            char:d | char:D)
                for ((i = 0; i < n; i++)); do TUI_STATES[i]="${TUI_DEFAULTS[$i]:-0}"; done ;;
            enter) rc=0; break ;;
            cancel | char:q | char:Q) rc=1; break ;;
        esac
        off="$(_tui_scroll "$cur" "$off" "$visible")"
    done
    _tui_erase
    _tui_end
    return $rc
}

# tui_confirm <question> [default:yes|no]
tui_confirm() {
    local question="$1" default="${2:-no}" saved_items=() saved_descs=() rc
    saved_items=("${TUI_ITEMS[@]}")
    saved_descs=("${TUI_DESCS[@]}")
    TUI_ITEMS=("Yes" "No")
    TUI_DESCS=("" "")
    local idx=1
    [[ "$default" == yes ]] && idx=0
    if tui_menu "$question" "$idx" && [[ "$TUI_CHOICE" == 0 ]]; then rc=0; else rc=1; fi
    TUI_ITEMS=("${saved_items[@]}")
    TUI_DESCS=("${saved_descs[@]}")
    return $rc
}
