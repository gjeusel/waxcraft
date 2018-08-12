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
antigen bundle z

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions

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

export TERM="xterm-256color"
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"

# Bind ctrl + space
bindkey '^ ' autosuggest-accept

vfzf() {
  _match_fzf="$(fzf --preview '[[ $(file --mime {}) =~ binary ]] &&
    echo {} is a binary file ||
    (highlight -O ansi -l {} ||
    coderay {} ||
    rougify {} ||
    cat {}) 2> /dev/null | head -500')"

  if [ -n "$_match_fzf" ]; then
    nvim "$_match_fzf"
  fi
}
# Bind ctrl + p  to fuzzy finder
# -s simulate keyboard entry
# (^U) to delete the whole line
# type fzf
# (^M) to execute the line
bindkey -s "^P" "^Uvfzf^M"
