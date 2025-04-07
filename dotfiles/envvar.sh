# ZSH config
export HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
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

# GO
export GOPATH="$HOME/.go"
export PATH="$GOPATH/bin:$PATH"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# CONDA
export CONDARC=$HOME/.config/conda/condarc

# K8S & plugin manager krew
export KUBECONFIG="$HOME/.config/kube/config"
export KREW_ROOT="$HOME/.config/krew"
export PATH="${KREW_ROOT}/bin:$PATH"

# Bat for color in terminal
export BAT_THEME="gruvbox-dark"

# Disable some default bindings added by zsh-vim-mode plugin
export VIM_MODE_TRACK_KEYMAP=no  # else it makes the terminal bug

# Enhancd
export ENHANCD_DISABLE_HYPHEN=1  # disable enhancd for "cd -"

# FZF theme (nord)
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
    --color=fg:#e5e9f0,bg+:#3b4252,hl:#81a1c1
    --color=fg+:#e5e9f0,bg+:#3b4252,hl+:#81a1c1
    --color=info:#eacb8a,prompt:#bf6069,pointer:#b48dac
    --color=marker:#a3be8b,spinner:#b48dac,header:#a3be8b
    --color=gutter:-1'

# Disable homebrew auto update on install
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

# tmux / iterm / others
export DISABLE_AUTO_TITLE='true'

# Annoying tools
export PYARROW_IGNORE_TIMEZONE=1
export SCW_DISABLE_CHECK_VERSION=true
export TURBO_NO_UPDATE_NOTIFIER=true
export VITE_CJS_IGNORE_WARNING=true
export ESLINT_USE_FLAT_CONFIG=true

# # Cargo restrict
# export CARGO_BUILD_JOBS=6
