export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

# Prevent oh-my-zsh/virtualenv plugin from prepending (venv_name) to prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1

plugins=(
  git
  docker
  python
  virtualenv
  command-not-found
  autoswitch_virtualenv
  zsh-autosuggestions
  zsh-syntax-highlighting
  z
  sudo
  extract
  dirhistory
  copypath
  jsontools
)

source $ZSH/oh-my-zsh.sh

# Use starship prompt
eval "$(starship init zsh)"
