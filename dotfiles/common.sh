# Which type of shell:
_shell="$(ps -p $$ --no-headers -o comm=)"

# To declare waxCraft PATH :
if [[ $_shell == "zsh" ]]; then
    export waxCraft_PATH=${0:A:h:h}
elif [[ $_shell == "bash" || $_shell == "sh" ]]; then
    export waxCraft_PATH="$(cd "$(dirname "$(dirname "$BASH_SOURCE" )")" && pwd)"
else
    echo "Unknown $_shell"
fi

# Deactivate ksshaskpass popup
unset SSH_ASKPASS

# Visual for yaourt help at fail:
export VISUAL="vim"

export LC_ALL=en_US.utf8
export LANG=en_US.utf8

export EDITOR=nvim
export GIT_EDITOR=nvim

# Colors {{{

# better yaourt colors
export YAOURT_COLORS="nb=1:pkg=1:ver=1;32:lver=1;45:installed=1;42:grp=1;34:od=1;41;5:votes=1;44:dsc=0:other=1;35"

# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors $waxCraft_PATH/dotfiles/.dircolors`"
    # DONE in .bash_aliases
    #alias ls='ls --color=auto'
    #alias dir='ls --color=auto --format=vertical'
    #alias vdir='ls --color=auto --format=long'
fi

#}}}

## Start tmux if installed
#if command -v tmux>/dev/null; then
#  [[ ! $TERM =~ screen ]] && [ -z $TMUX ] && exec tmux
#fi

# Source aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
