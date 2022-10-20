# ZSH config
export HISTFILE=~/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

export CASE_SENSITIVE=true  # prefer case sensitive complete
#export RM_STAR_SILENT=true  # silent security yes/no on rm *

# Styling
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
export PURE_PROMPT_SYMBOL="λ"

# Editor config
export EDITOR=nvim
export GIT_EDITOR=nvim
export VISUAL="nvim"

# nnn config
export NNN_USE_EDITOR=1  # Open text files in $EDITOR ($VISUAL, if defined; fallback vi)
export NNN_OPENER_DETACH=1  # do not block when invoking file opener

# Python Config
export PYTHONSTARTUP=$HOME/.python_startup.py

# Bat for color in terminal
export BAT_THEME="gruvbox-dark"

# Disable some default bindings added by zsh-vim-mode plugin
export VIM_MODE_TRACK_KEYMAP=no  # else it makes the terminal bug

# Enhancd
export ENHANCD_DISABLE_HYPHEN=1  # disable enhancd for "cd -"

# Disable homebrew auto update on install
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1
