# # To debug:
# set -x

# _______ ZSH NOTES _______
#
# Variables that can be overwritten:
#   - ZDOTDIR (folder in which to put zsh files)
#   - CONDA_HOME (influence lazy load of conda)

# Used by aliases
export WAXPATH=${0:A:h:h}

source "$WAXPATH/zsh/envvar.sh"

source "$WAXPATH/zsh/functions/fzf-extras.zsh"
source "$WAXPATH/zsh/functions/fzf-git.sh"
_fzf_git_fzf() {
  fzf-tmux -p80%,60% -- \
    --layout=reverse --multi --height=50% --min-height=20 \
    --border-label-pos=2 \
    --color='header:italic:underline,label:blue' \
    --preview-window='right,50%,border-left' \
    --bind='ctrl-/:change-preview-window(down,50%,border-rounded|hidden|)' "$@"
}

# _______ ZSH Options _______

# History - https://zsh.sourceforge.io/Doc/Release/Options.html#index-APPENDHISTORY
setopt append_history

setopt no_inc_append_history
setopt share_history           # Share history accross shells

setopt hist_expire_dups_first  # Expire a duplicate event first when trimming history.
setopt hist_ignore_dups        # Do not record an event that was just recorded again.
setopt hist_ignore_all_dups    # Delete an old recorded event if a new event is a duplicate.
setopt hist_find_no_dups       # Do not display a previously found event.
setopt hist_save_no_dups       # Do not write a duplicate event to the history file.
setopt hist_ignore_space       # Do not write to history commands starting with a space.
setopt hist_no_functions       # Do not add function definitions in the history
setopt hist_no_store           # Do not add the command "history" in the history
# setopt hist_reduce_blanks    # not wanted as it removes multiline \

# Other
#setopt autocd extendedglob notify nomatch autopushd pushdignoredups promptsubst

# don't nice background tasks
#setopt no_bg_nice no_hup no_beep

# _______ ZSH Modules config _______

# ctrl-x to edit current command in $EDITOR:
autoload -U edit-command-line
zle -N edit-command-line

# Add Vi text-objects for brackets and quotes
autoload -Uz select-bracketed select-quoted
zle -N select-quoted
zle -N select-bracketed
for km in viopp visual; do
  bindkey -M $km -- '-' vi-up-line-or-history
  for c in {a,i}${(s..)^:-\'\"\`\|,./:;=+@}; do
    bindkey -M $km $c select-quoted
  done
  for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
    bindkey -M $km $c select-bracketed
  done
done

# --- Autocompletion ---

# Curated completions:
#  for (docker + docker-compose):
#  - docker: using the dynamic comp
#  - docker-compose
#  - scw: comes from `scw autocomplete script shell=zsh`, but stripped from an added `zcompinit` which slowed down things
fpath+="$WAXPATH/zsh/completions"

# shell user completion:
fpath+="${ZDOTDIR:-$HOME}/.zfunc"

# brew and installed with brew completions:
if type brew &>/dev/null; then
  fpath+="$(brew --prefix)/share/zsh/site-functions"
fi

# Notes:
#   We prefer to manually re-build the cache (found no good automated solution)
autoload -Uz compinit
#
# to rebuild cache, run:
# > compinit

# --- Fine tuning completion ---
# https://thevaluable.dev/zsh-completion-guide-examples/
#
# `zstyle <pattern> <style> <values>`
#
# pattern:
# `:completion:<function>:<completer>:<command>:<argument>:<tag>`

# enable cache:
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${ZDOTDIR:-$HOME}/.zcompcache"

local _ignored_patterns=(
  '(|*/)__pycache__'
  '(|*/)*.egg-info'
  '(*/)#lost+found'
)

# Ignore these everywhere
zstyle ':completion:*:*:*' ignored-patterns $_ignored_patterns

# Set accept-exact-dirs for cases of mounted drives (Google Drive or S3-bucket)
# to avoid slow down searching on parent directory
# https://github.com/ohmyzsh/ohmyzsh/issues/7348
zstyle ':completion:*' accept-exact-dirs true

# Ask for a menu instead of blindly cycling:
zstyle ':completion:*' menu select

# Add a title to the completion when specific commands
zstyle ':completion:*:*:(ls|cd|cp):*:descriptions' format '%F{green}-- %d --%f'

# Add info on number of errors corrected on completion
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'

# Add messages:
zstyle ':completion:*:messages' format ' %F{magenta} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'


# _______ Setups before plugin sourcing _______

# Make sure to have binaries in PATH before sourcing zinit
# else tmux is not yet available and it messes up startup
if [[ -f /opt/homebrew/bin/brew && -z "$TMUX" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# _______ ZSH Plugins _______
#
# - profile zinit, run: `zinit times`

ZINIT_HOME="${ZDOTDIR:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit ice pick"async.zsh" src"pure.zsh"
zinit light sindresorhus/pure

zinit ice wait lucid
zinit light zsh-users/zsh-history-substring-search  # history ctrl-p / arrow up

zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting       # syntax highlight

# load zsh-completion on (see: https://github.com/zdharma-continuum/zinit/discussions/515)
zinit for \
    atload"zicompinit; zicdreplay" \
    blockf \
    lucid \
    wait \
  @zsh-users/zsh-completions               # additional completion

zinit ice wait lucid atload'_zsh_autosuggest_start'
zinit light zsh-users/zsh-autosuggestions           # inline completion

# # NOTE: can't lazy load fzf-tab else buggy with autosuggestions
# zinit ice wait lucid
zinit light Aloxaf/fzf-tab                          # fzf for tab completion
# fzf-tab nord theme (it can't use FZF_DEFAULT_OPTS, see: https://github.com/Aloxaf/fzf-tab/issues/463)
zstyle ':fzf-tab:*' fzf-flags --color fg:#e5e9f0,bg+:#3b4252,hl:#81a1c1,fg+:#e5e9f0,bg+:#3b4252,hl+:#81a1c1,info:#eacb8a,prompt:#bf6069,pointer:#b48dac,marker:#a3be8b,spinner:#b48dac,header:#a3be8b,gutter:-1 --pointer=''

# snippets
for snip in common-aliases kubectx kubectl tmux; do
    zinit ice wait lucid
    zinit snippet OMZP::$snip
done

# zinit ice wait lucid trigger-load'!git'
zinit snippet OMZP::git
zinit ice wait lucid trigger-load'!extract'
zinit snippet OMZP::extract
# zinit ice wait lucid trigger-load'!gcloud'
# zinit snippet OMZP::gcloud
# zinit ice wait lucid trigger-load'!aws'
# zinit snippet OMZP::aws

# # NOTE: in case of non-interactive shells (claude code), force load to avoid errors
# if [[ ! $- == *i* ]]; then
#   zinit load path:plugins/git
# fi

# _______ TMUX Plugins _______

# Auto install tpm (tmux plugin)
[ -n "$TMUX" ] && export TERM=screen-256color
if [ ! -e "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# _______ Setups after plugin sourcing _______

# Source bindings (after source plugins so we got all widgets defined)
source "$WAXPATH/zsh/bindings.zsh"

source "$WAXPATH/zsh/aliases.zsh"

# _______ completions _______

# Fzf conf
if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
fi

# kubectl conf
if command -v kubectl &> /dev/null; then
  source <(kubectl completion zsh)
fi

