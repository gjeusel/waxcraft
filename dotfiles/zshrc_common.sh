# Source common to bash & zsh:
source "/${0:1:h}/common.sh"

_dotfile_dir="/${0:1:h}"

if [ ! -e "$HOME/.config/antigen.zsh" ]; then
  curl -L git.io/antigen -o "$HOME/.config/antigen.zsh"
fi
source "$HOME/.config/antigen.zsh"

HISTFILE=~/.zsh_history

autoload -U zargs
setopt inc_append_history share_history autocd extendedglob notify nomatch autopushd pushdignoredups promptsubst

# Save a lot of time at startup:
skip_global_compinit=1

autoload -U promptinit
promptinit

autoload bashcompinit
bashcompinit

#ENABLE_CORRECTION="true"
CASE_SENSITIVE=true
RM_STAR_SILENT=true
TranslateWheelToCursor=on
DisableWheelToCursorByCtrl=on

# Plugins
antigen use oh-my-zsh
antigen bundle git
antigen bundle extract  # generic cmd to decompress files
antigen bundle colored-man-pages
antigen bundle common-aliases
antigen bundle tmux
#antigen bundle z
#antigen bundle jsontools

#antigen bundle docker
#antigen bundle redis-cli
#antigen bundle ansible

#antigen bundle archlinux
#antigen bundle yum
#antigen bundle ytet5uy4/pctl

# Python:
#antigen bundle "esc/conda-zsh-completion"
#antigen bundle "bckim92/zsh-autoswitch-conda"
antigen bundle pip
#antigen bundle celery

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions

## Theme

## Spaceship:
#antigen theme https://github.com/denysdovhan/spaceship-prompt spaceship
##SPACESHIP_TIME_SHOW=true
#SPACESHIP_CHAR_SYMBOL="❯ "
#SPACESHIP_USER_SHOW="needed"
#SPACESHIP_USER_PREFIX=" "
#SPACESHIP_HOST_PREFIX="@"
#SPACESHIP_GIT_BRANCH_COLOR="cyan"

## Pure:
antigen bundle mafredri/zsh-async
antigen bundle sindresorhus/pure
# For pure & conda, see:
# https://github.com/sindresorhus/pure/issues/411
# For pure on remote, user must be part of tty group to get access to zsh-async correctly

# Tell Antigen that you're done.
antigen apply

# Set up Node Version Manager
if [ -f "/usr/share/nvm/init-nvm.sh" ]; then
    source /usr/share/nvm/init-nvm.sh

    # See https://github.com/robbyrussell/oh-my-zsh/issues/6163
    if [ -d $HOME/.nvm ]; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        #[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    fi
fi

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"

# Bind ctrl + space
bindkey '^ ' autosuggest-accept

# Bind ctrl + p  to fuzzy finder
# -s simulate keyboard entry
# (^U) to delete the whole line
# type fzf
# (^M) to execute the line
bindkey -s "^P" "^Uvfzf^M"

# Bind ctrl + n for nnn
bindkey -s "^N" "^Unnn^M"

# Auto install tpm (tmux plugin) ?
#export TERM="tmux-256color"
[ -n "$TMUX" ] && export TERM=screen-256color
if [ ! -e "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
