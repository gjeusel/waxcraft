_dotfile_dir="/${0:1:h}"

# Source common to bash & zsh:
source "/${0:1:h}/common.sh"

# Source zsh antigen
source "$_dotfile_dir/antigen.zsh"

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

ENABLE_CORRECTION="true"
CASE_SENSITIVE="true"
TranslateWheelToCursor=on
DisableWheelToCursorByCtrl=on

# Plugins
antigen bundle git
antigen bundle extract
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


antigen bundle zsh-users/zsh-syntax-highlighting

# Theme
antigen theme https://github.com/denysdovhan/spaceship-prompt spaceship
SPACESHIP_TIME_SHOW=true

# Tell Antigen that you're done.
antigen apply
