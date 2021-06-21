# Used by aliases
export waxCraft_PATH=${0:A:h:h}
source "$waxCraft_PATH/dotfiles/envvar.sh"
source "$waxCraft_PATH/dotfiles/fzf-extras.zsh"

autoload -U edit-command-line

# Some options settings:
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

fpath=("$waxCraft_PATH/dotfiles/completions" $fpath)

autoload -Uz compinit
# Check compinit cache once per day
if [ $(date +'%j') != $(/usr/bin/stat -f '%Sm' -t '%j' ${ZDOTDIR:-$HOME}/.zcompdump) ]; then
  compinit
else
  compinit -C
fi

# PLUGINS
# Auto-download antibody binary
if [ ! which gls >/dev/null 2>&1 ]; then
  curl -sfL git.io/antibody | sh -s - -b /usr/local/bin
fi

# Make sure to have binaries in PATH before sourcing antibody
# else tmux is not yet available and it messes up iterm2 startup
if [ -f  /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Static load, when change of plugins run:
# # antibody bundle < "$waxCraft_PATH/dotfiles/.zsh-plugins.txt" > ~/.zsh-plugins.sh
source "$HOME/.zsh-plugins.sh"

# AUTO COMPLETION
# Ignore these everywhere except for rm
zstyle ':completion:*:*:*' ignored-patterns '(|*/)__pycache__' \
    '(|*/)*.egg-info' '(*/)#lost+found'
zstyle ':completion:*:rm:*' ignored-patterns '(|*/)*.egg-info'

# Set accept-exact-dirs for cases of mounted drives (Google Drive or S3-bucket)
# to avoid slow down searching on parent directory
# https://github.com/ohmyzsh/ohmyzsh/issues/7348
zstyle ':completion:*' accept-exact-dirs true

# Auto install tpm (tmux plugin)
#export TERM="tmux-256color"
[ -n "$TMUX" ] && export TERM=screen-256color
if [ ! -e "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi


# Source bindings
source "$waxCraft_PATH/dotfiles/bindings.zsh"

#### ZSH STARTUP OPTIM

# RVM ( Ruby Versin Manager )
rmv() {
  if [ -f "$HOME/.rvm/scripts/rvm" ]; then
    source /Users/jd5584/.rvm/scripts/rvm
    rvm "$@"
  else:
    echo "rvm is not installed" >&2
    return 1
  fi
}

## Only add in zsh history commnds that did not failed
#zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }
