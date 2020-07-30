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

# backward and forward word with option+left/right
bindkey '^[b' backward-word
bindkey '^[f' forward-word
# backward and forward word with ctrl+left/right
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# delete word with option+backspace
bindkey '^[^H' backward-delete-word

# delete char
bindkey "^[[3~" delete-char

# beginning / end of line
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# edit command line in $EDITOR
bindkey '^X' edit-command-line

# Hist search
bindkey '^r' history-incremental-search-backward
bindkey '^R' history-incremental-pattern-search-backward

# Hist search completion of line with arrows up and down
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

zle -N edit-command-line


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

# Static load, when change of plugins run:
# antibody bundle < "$waxCraft_PATH/dotfiles/.zsh-plugins.txt" > "$waxCraft_PATH/dotfiles/.zsh-plugins.sh"
source "$waxCraft_PATH/dotfiles/.zsh-plugins.sh"

# AUTO COMPLETION
# Ignore these everywhere except for rm
zstyle ':completion:*:*:*' ignored-patterns '(|*/)__pycache__' \
    '(|*/)*.egg-info' '(*/)#lost+found'
zstyle ':completion:*:rm:*' ignored-patterns '(|*/)*.egg-info'

# Bind ctrl + space
bindkey '^ ' autosuggest-accept

# Auto install tpm (tmux plugin)
#export TERM="tmux-256color"
[ -n "$TMUX" ] && export TERM=screen-256color
if [ ! -e "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi


#### ZSH STARTUP OPTIM

# Set up Node Version Manager
nvm() {
  # On first use, it will set nvm up properly which will replace the `nvm`
  # shell function with the real one
  if [ -f "/usr/share/nvm/init-nvm.sh" ]; then
    source /usr/share/nvm/init-nvm.sh
    # See https://github.com/robbyrussell/oh-my-zsh/issues/6163
    if [ -d $HOME/.nvm ]; then
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    fi
    nvm "$@"
  else:
    echo "nvm is not installed" >&2
    return 1
  fi
}

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
