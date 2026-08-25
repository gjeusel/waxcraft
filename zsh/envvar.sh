# ZSH config
export HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
export HISTSIZE=100000
export SAVEHIST=100000

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

#export RM_STAR_SILENT=true  # silent security yes/no on rm *

# Styling
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"
export PURE_PROMPT_SYMBOL="λ"

# Editor config
export EDITOR=nvim
export GIT_EDITOR=nvim
export VISUAL="nvim"

# Python Config
export PYTHONSTARTUP=$HOME/.config/python/startup.py
export IPYTHONDIR=$HOME/.config/ipython
export PTPYTHON_CONFIG_HOME=$HOME/.config/ptpython

# GO
export GOPATH="$HOME/.go"
export PATH="$GOPATH/bin:$PATH"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Node.js package managers
export NPM_CONFIG_PREFIX="$HOME/.local"
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$HOME/.local/bin:$PNPM_HOME/bin:$PNPM_HOME:$PATH"

# CONDA
export CONDARC=$HOME/.config/conda/condarc

# K8S & plugin manager krew
export KUBECONFIG="$HOME/.config/kube/config"
export KREW_ROOT="$HOME/.config/krew"
export PATH="${KREW_ROOT}/bin:$PATH"

# PSQL
export PSQL_HISTORY="$HOME/.cache/psql_history"

# # TMUXP
# export TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins"

# Bat for color in terminal
export BAT_THEME="gruvbox-dark"

# FFF
export FFF_ENABLE_HOME_SCAN=0

# FZF theme (nord)
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
    --pointer=''
    --color=fg:#e5e9f0,bg+:#3b4252,hl:#81a1c1
    --color=fg+:#e5e9f0,bg+:#3b4252,hl+:#81a1c1
    --color=info:#eacb8a,prompt:#bf6069,pointer:#b48dac
    --color=marker:#a3be8b,spinner:#b48dac,header:#a3be8b
    --color=gutter:-1'

# FZF configuration with find
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow \
  --exclude .git \
  --exclude node_modules \
  --exclude .cache \
  --exclude .venv \
  --exclude .mypy \
  --exclude venv \
  --exclude __pycache__ \
  --exclude '*.pyc' \
  --exclude '*.pyo' \
  --exclude '*.class' \
  --exclude '*.o' \
  --exclude '*.so' \
  --exclude '*.swp' \
  --exclude '*.swo' \
  --exclude '.DS_Store' \
  --exclude '*.log'"

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

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

# Pi Agent
export PI_SKIP_VERSION_CHECK=true

# @tintinweb/pi-tasks
export PI_TASKS="/tmp/pi-tasks-${USER}.json"

# # Cargo restrict
# export CARGO_BUILD_JOBS=6
