_dotfile_dir="/${0:1:h}"

# Source zsh antigen
source "$_dotfile_dir/antigen.zsh"

autoload -U zargs
setopt appendhistory autocd extendedglob notify nomatch autopushd pushdignoredups promptsubst

autoload -Uz compinit
compinit -i

autoload -U promptinit
promptinit

autoload bashcompinit
bashcompinit

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

#ENABLE_CORRECTION="true"
CASE_SENSITIVE=true
RM_STAR_SILENT=true
TranslateWheelToCursor=on
DisableWheelToCursorByCtrl=on

# Plugins
antigen bundle git
antigen bundle extract  # generic cmd to decompress files
antigen bundle colored-man-pages
antigen bundle common-aliases
antigen bundle docker
antigen bundle jsontools
antigen bundle pep8
antigen bundle autopep8
antigen bundle pip
antigen bundle pyenv
antigen bundle pylint
antigen bundle python
antigen bundle redis-cli
antigen bundle tmux
antigen bundle archlinux
antigen bundle ytet5uy4/pctl


antigen bundle clvv/fasd  # better than z

antigen bundle zsh-users/zsh-syntax-highlighting

# Theme
antigen theme https://github.com/denysdovhan/spaceship-prompt spaceship
SPACESHIP_TIME_SHOW=true
SPACESHIP_CHAR_SYMBOL="❯ "

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

# Up for case if proxy set
# Source common to bash & zsh:
source "/${0:1:h}/common.sh"

if type "fasd" > /dev/null; then
    fasd_cache="$HOME/.fasd-init-bash"
    eval "$(fasd --init posix-alias bash-hook bash-ccomp bash-ccomp-install >| '$fasd_cache')"
    source "$fasd_cache"
    unset fasd_cache
fi
alias v='f -e nvim' # quick opening files with vim
