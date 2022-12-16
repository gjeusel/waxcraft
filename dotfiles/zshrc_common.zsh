# # To debug:
# set -x

# _______ ZSH NOTES _______
#
# - [How to check if command exists](https://stackoverflow.com/a/39983422/17973851)
# - [How to do conditions](https://zsh.sourceforge.io/Doc/Release/Conditional-Expressions.html)

# Used by aliases
export waxCraft_PATH=${0:A:h:h}

source "$waxCraft_PATH/dotfiles/envvar.sh"
source "$waxCraft_PATH/dotfiles/fzf-extras.zsh"

# _______ ZSH Options _______

# History
setopt appendhistory
setopt inc_append_history
setopt share_history

#setopt hist_ignore_all_dups hist_ignore_dups hist_expire_dups_first
#setopt hist_reduce_blanks hist_ignore_space
#setopt hist_reduce_blanks hist_ignore_space hist_verify

# Other
#setopt autocd extendedglob notify nomatch autopushd pushdignoredups promptsubst

# don't nice background tasks
#setopt no_bg_nice no_hup no_beep

# _______ ZSH Modules config _______

# --- Edit Command Line ---
autoload -U edit-command-line
zle -N edit-command-line

# --- Autocompletion ---

# versioned completions (docker + docker-compose):
fpath=("$waxCraft_PATH/dotfiles/completions" $fpath)

# shell user completion:
# fpath=("$HOME/.zfunc" $fpath)

# create ~/.zfunc if missing
if [[ ! -d $HOME/.zfunc ]]; then
  mkdir ~/.zfunc
fi

# auto generate kubectl completion if needed:
if [[ (! -f $HOME/.zfunc/_kubectl) && (( $+commands[kubectl] ))]]; then
  kubectl completion zsh &> $HOME/.zfunc/_kubectl
fi

# brew and installed with brew completions:
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Notes:
#   We prefer to manually re-build the cache (instead of the known trick to auto rebuild the cache each day once)
#   as it should be done after loading the entire ~/.zshrc
#   Maybe split this file in two with a `before_zshrc.zsh` and `after_zshrc.zsh` ?
autoload -Uz compinit
compinit -i -C
# to rebuild cache, run:
# > compinit

## PERF: rebuild cache once per day
# if [[ (! -f ~/.zcompdump ) || $(date +'%j') != $(stat -f '%Sm' -t '%j' ~/.zcompdump) ]]; then
#   echo "Building zsh completion cache..."
#   # -i to ignore insecure directories and files
#   # compinit -i
#   compinit
# else
#   compinit -C
# fi
# compinit -C

# --- Fine tuning ---

# Ignore these everywhere except for rm
zstyle ':completion:*:*:*' ignored-patterns '(|*/)__pycache__' \
    '(|*/)*.egg-info' '(*/)#lost+found'
zstyle ':completion:*:rm:*' ignored-patterns '(|*/)*.egg-info'

# Set accept-exact-dirs for cases of mounted drives (Google Drive or S3-bucket)
# to avoid slow down searching on parent directory
# https://github.com/ohmyzsh/ohmyzsh/issues/7348
zstyle ':completion:*' accept-exact-dirs true


# _______ Setups before plugin sourcing _______

# Make sure to have binaries in PATH before sourcing antibody
# else tmux is not yet available and it messes up iterm2 startup
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# _______ ZSH Plugins _______
#
# https://getantidote.github.io/
# brew install antidote

if [[ (! -d ${ZDOTDIR:-~}/.antidote) && (( $+commands[git] )) ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote
fi

source ${ZDOTDIR:-~}/.antidote/antidote.zsh

# # Static load, when change of plugins run:
# antidote bundle < "$waxCraft_PATH/dotfiles/.zsh-plugins.txt" > ~/.zsh-plugins.zsh
if [ -f ${ZDOTDIR:-~}/.zsh-plugins.zsh ]; then
  source ${ZDOTDIR:-~}/.zsh-plugins.zsh
fi

# Auto install tpm (tmux plugin)
#export TERM="tmux-256color"
[ -n "$TMUX" ] && export TERM=screen-256color
if [ ! -e "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi


# _______ Setups after plugin sourcing _______

# Source bindings (after source plugins so we got all widgets defined)
source "$waxCraft_PATH/dotfiles/bindings.zsh"


# _______ ZSH startup optims _______

# # RVM ( Ruby Versin Manager )
# rmv() {
#   if [ -f "$HOME/.rvm/scripts/rvm" ]; then
#     source $HOME/.rvm/scripts/rvm
#     rvm "$@"
#   else:
#     echo "rvm is not installed" >&2
#     return 1
#   fi
# }

## Only add in zsh history commnds that did not failed
#zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }
