# # To debug:
# set -x

# _______ ZSH NOTES _______
#
# - [How to check if command exists](https://stackoverflow.com/a/39983422/17973851)
# - [How to do conditions](https://zsh.sourceforge.io/Doc/Release/Conditional-Expressions.html)

# Used by aliases
export waxCraft_PATH=${0:A:h:h}
export WAXPATH=${waxCraft_PATH}

source "$waxCraft_PATH/dotfiles/envvar.sh"
source "$waxCraft_PATH/dotfiles/fzf-extras.zsh"

source "$waxCraft_PATH/dotfiles/fzf-git.sh"
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
setopt appendhistory
setopt inc_append_history
# setopt share_history           # Share history accross shells

setopt hist_expire_dups_first  # Expire a duplicate event first when trimming history.
setopt hist_ignore_dups        # Do not record an event that was just recorded again.
setopt hist_ignore_all_dups    # Delete an old recorded event if a new event is a duplicate.
setopt hist_find_no_dups       # Do not display a previously found event.
setopt hist_save_no_dups       # Do not write a duplicate event to the history file.
setopt hist_ignore_space       # Do not write to history commands starting with a space.

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

# our own completions for (docker + docker-compose):
fpath+="$waxCraft_PATH/dotfiles/completions"

# NOTE: Scaleway CLI autocomplete initialization.
# scaleway autocomplete script is calling itself compinit, which is a mistake.
# eval "$(scw autocomplete script shell=zsh)"
# FIX:
# > scw autocomplete script shell=zsh &> ~/.zfunc/_scw
# edit ~/.zfunc/_scw and remove first line calling compinit
# > rm ~/.zcompdump

# shell user completion:
fpath+="${ZDOTDIR:-$HOME}/.zfunc"

# brew and installed with brew completions:
if type brew &>/dev/null; then
  fpath+="$(brew --prefix)/share/zsh/site-functions"
fi

# Notes:
#   We prefer to manually re-build the cache (instead of the known trick to auto rebuild the cache each day once)
#   as it should be done after loading the entire ~/.zshrc
#   Maybe split this file in two with a `before_zshrc.zsh` and `after_zshrc.zsh` ?
autoload -Uz compinit
#
# -i silently ignore all insecure files and directories
# -D turn off generation of cache ~/.zcompdump
# -c do not check function name changes ()
compinit -i -c -D
#
# to rebuild cache, run:
# > compinit

## PERF: rebuild cache once per day
# if [[ (! -f ~/.zcompdump ) || $(date +'%j') != $(stat -f '%Sm' -t '%j' ~/.zcompdump) ]]; then
#   echo "Building zsh completion cache..."
#   # -i to ignore insecure directories and files
#   # compinit -i
#   compinit
# else
#   compinit -C
# fi
# compinit -C

# --- Fine tuning ---
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

# Make sure to have binaries in PATH before sourcing antibody
# else tmux is not yet available and it messes up startup
if [[ -f /opt/homebrew/bin/brew && -z "$TMUX" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# _______ ZSH Plugins _______
#
# https://getantidote.github.io/
# brew install antidote
if [[ (! -d ${ZDOTDIR:-$HOME}/.antidote) && (( $+commands[git] )) ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-$HOME}/.antidote
fi
source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh

# # Static load, when change of plugins run:
# antidote bundle < "$waxCraft_PATH/dotfiles/.zsh-plugins.txt" > ~/.zsh-plugins.zsh
if [ -f ${ZDOTDIR:-$HOME}/.zsh-plugins.zsh ]; then
  source ${ZDOTDIR:-$HOME}/.zsh-plugins.zsh
fi

# Auto install tpm (tmux plugin)
#export TERM="tmux-256color"
[ -n "$TMUX" ] && export TERM=screen-256color
if [ ! -e "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi


# _______ Setups after plugin sourcing _______

# Source bindings (after source plugins so we got all widgets defined)
source "$waxCraft_PATH/dotfiles/bindings.zsh"

# _______ Fixes / Optims _______

# Avoid issues trying to list all directories in a mounted S3
# https://github.com/b4b4r07/enhancd/issues/85
__enhancd::filter::exists()
{
   local line
   while read line
   do
       if [[ $line == $HOME/s3/* || -d $line ]]; then
           echo "$line"
       fi
   done
}
