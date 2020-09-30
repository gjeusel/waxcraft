# ZSH config
export HISTFILE=~/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

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
export BAT_THEME="gruvbox"
