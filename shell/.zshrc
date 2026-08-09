# Path to Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"

# Disable oh-my-zsh theme — we use Starship
ZSH_THEME=""

# Auto-update oh-my-zsh without prompting
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Completion dots while waiting
COMPLETION_WAITING_DOTS="%F{yellow}...%f"

# History timestamps
HIST_STAMPS="yyyy-mm-dd"

# Plugins
plugins=(
  git                           # git aliases & completions
  docker                        # docker completions
  docker-compose                # docker-compose completions
  pip                           # pip completions
  python                        # python aliases
  sudo                          # press Esc twice to prepend sudo
  copypath                      # copy current path to clipboard
  dirhistory                    # Alt+Left/Right to navigate dir history
  jsontools                     # pp_json, is_json, urlencode/decode
  colored-man-pages             # colorful man pages
  command-not-found             # suggest packages for unknown commands
  zsh-history-substring-search  # Up/Down searches history by substring
  you-should-use                # reminds you of aliases you've set
)

source $ZSH/oh-my-zsh.sh

# ─── Environment ──────────────────────────────────────────────────────
export SUDO_EDITOR="$EDITOR"
export BAT_THEME=ansi
export PATH="$PATH:$HOME/.local/bin"

# Omarchy (Arch only) — skipped cleanly on other distros
if [[ -d "$HOME/.local/share/omarchy" ]]; then
  export OMARCHY_PATH=$HOME/.local/share/omarchy
  export PATH=$OMARCHY_PATH/bin:$PATH
fi

# Debian/PikaOS ship bat and fd as batcat/fdfind
if (( ! $+commands[bat] )) && (( $+commands[batcat] )); then
  alias bat='batcat'
fi
if (( ! $+commands[fd] )) && (( $+commands[fdfind] )); then
  alias fd='fdfind'
fi

# ─── History ──────────────────────────────────────────────────────────
HISTSIZE=32768
SAVEHIST=32768
setopt HIST_IGNORE_ALL_DUPS   # no duplicate entries
setopt HIST_IGNORE_SPACE      # ignore commands starting with space
setopt HIST_REDUCE_BLANKS     # remove extra blanks
setopt SHARE_HISTORY          # share history across sessions
setopt INC_APPEND_HISTORY     # write immediately, not on exit

# ─── Completion tuning ────────────────────────────────────────────────
setopt AUTO_CD                # type a dir name to cd into it
setopt CORRECT                # suggest corrections for typos
setopt COMPLETE_IN_WORD       # complete from both ends of a word
setopt AUTO_MENU              # show completion menu on tab
setopt ALWAYS_TO_END          # move cursor to end after completion

zstyle ':completion:*' menu select                          # arrow-key menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # colored completions
zstyle ':completion:*' group-name ''                        # group by category
zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'

# ─── Aliases ──────────────────────────────────────────────────────────
# File system
if command -v eza &> /dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

# fzf preview needs a real binary name (aliases don't expand inside it)
_bat_bin="$(command -v bat || command -v batcat)"
if [[ -n "$_bat_bin" ]]; then
  _file_preview="$_bat_bin --style=numbers --color=always {}"
else
  _file_preview="cat {}"
fi
if [[ "$TERM" == "xterm-kitty" ]]; then
  alias ff="fzf --preview 'case \$(file --mime-type -b {}) in image/*) kitty icat --clear --transfer-mode=memory --stdin=no --place=\${FZF_PREVIEW_COLUMNS}x\${FZF_PREVIEW_LINES}@0x0 {} ;; *) $_file_preview ;; esac'"
else
  alias ff="fzf --preview '$_file_preview'"
fi
unset _bat_bin _file_preview
alias eff='$EDITOR "$(ff)"'
sff() { if [ $# -eq 0 ]; then echo "Usage: sff <destination> (e.g. sff host:/tmp/)"; return 1; fi; local file; file=$(find . -type f -printf '%T@\t%p\n' | sort -rn | cut -f2- | ff) && [ -n "$file" ] && scp "$file" "$1"; }

# Smart cd with zoxide
if command -v zoxide &> /dev/null; then
  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi
      printf "\U000F17A9 "
      pwd
    fi
  }
fi

open() (
  xdg-open "$@" >/dev/null 2>&1 &
)

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias c='opencode'
alias cx='printf "\033[2J\033[3J\033[H" && claude --allow-dangerously-skip-permissions'
alias d='docker'
alias r='rails'
alias t='tmux attach || tmux new -s Work'
n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }

# Git
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# ─── Source Omarchy bash functions (Arch only, compatible with zsh) ──
# Skip worktrees (conflicts with oh-my-zsh git 'ga' alias) — ported below
if [[ -n "${OMARCHY_PATH:-}" && -d "$OMARCHY_PATH/default/bash/fns" ]]; then
  for fn_file in "$OMARCHY_PATH"/default/bash/fns/*(N); do
    [[ -f "$fn_file" && "$(basename "$fn_file")" != "worktrees" ]] && source "$fn_file"
  done
  unset fn_file
fi

# Worktree functions (ported from omarchy, renamed to avoid git plugin conflict)
# Use wta/wtd instead of ga/gd (ga/gwta taken by oh-my-zsh git plugin)
wta() {
  if [[ -z "$1" ]]; then
    echo "Usage: wta [branch name]"
    return 1
  fi
  local branch="$1"
  local base="$(basename "$PWD")"
  local wt_path="../${base}--${branch}"
  git worktree add -b "$branch" "$wt_path"
  command -v mise &> /dev/null && mise trust "$wt_path"
  cd "$wt_path"
}

wtd() {
  if gum confirm "Remove worktree and branch?"; then
    local cwd base branch root worktree
    cwd="$(pwd)"
    worktree="$(basename "$cwd")"
    root="${worktree%%--*}"
    branch="${worktree#*--}"
    if [[ "$root" != "$worktree" ]]; then
      cd "../$root"
      git worktree remove "$cwd" --force || return 1
      git branch -D "$branch"
    fi
  fi
}

# ─── Tool initializations ────────────────────────────────────────────
# mise (tool version manager)
if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# Starship prompt
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# zoxide (smart cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# try (task management)
if command -v try &> /dev/null; then
  eval "$(SHELL=/bin/zsh command try init ~/Work/tries)"
fi

# fzf (Arch: /usr/share/fzf, Debian/PikaOS: /usr/share/doc/fzf/examples)
if command -v fzf &> /dev/null; then
  for _fzf_file in /usr/share/fzf/completion.zsh /usr/share/fzf/key-bindings.zsh \
                   /usr/share/doc/fzf/examples/completion.zsh /usr/share/doc/fzf/examples/key-bindings.zsh; do
    [[ -f "$_fzf_file" ]] && source "$_fzf_file"
  done
  unset _fzf_file
fi

# ─── System zsh plugins (Arch and Debian package layouts) ────────────
for _plugin_file in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
                    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -f "$_plugin_file" ]]; then source "$_plugin_file"; break; fi
done
for _plugin_file in /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
                    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -f "$_plugin_file" ]]; then source "$_plugin_file"; break; fi
done
unset _plugin_file

# Autosuggestion config
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#888888"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# History substring search keybindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ─── pyenv ────────────────────────────────────────────────────────────
if [[ -d "$HOME/.pyenv/bin" ]]; then
  export PATH="$HOME/.pyenv/bin:$PATH"
fi
if command -v pyenv &> /dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv virtualenv-init -)"
fi

# ─── Cargo/uv env (if present) ───────────────────────────────────────
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# ─── Machine-local overrides ─────────────────────────────────────────
# Hardware-specific exports (e.g. ROCm HSA_OVERRIDE_GFX_VERSION), secrets,
# and anything that shouldn't live in the dotfiles repo.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
