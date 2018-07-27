_dotfile_dir="/${0:1:h}"

# Source zsh antigen
source "$_dotfile_dir/antigen.zsh"

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


antigen bundle zsh-users/zsh-syntax-highlighting

# Theme
antigen theme https://github.com/denysdovhan/spaceship-prompt spaceship
SPACESHIP_TIME_SHOW=true
SPACESHIP_CHAR_SYMBOL="❯ "

# Tell Antigen that you're done.
antigen apply

# Source common to bash & zsh:
source "/${0:1:h}/common.sh"
