# If not running interactively, don't do anything
if [ -z "$PS1"  ]; then return; fi

# To declare waxCraft PATH :
#export waxCraft_PATH="$(cd "$(dirname "$(dirname $(readlink "${HOME}/.bash_aliases"))")" && pwd)"
export waxCraft_PATH="$(cd "$(dirname "$(dirname "$BASH_SOURCE" )")" && pwd)"

# Deactivate ksshaskpass popup
unset SSH_ASKPASS

# Visual for yaourt help at fail:
export VISUAL="vim"

# To adds a * to the branch name if the branch has been changed
export GIT_PS1_SHOWDIRTYSTATE=1
#export EDITOR=vim
#export GIT_EDITOR=

# Get colors codes:
source $waxCraft_PATH/dotfiles/.codecolors.sh

# Prompt shell setup : {{{
##################################################
ps1_construct_init="\n"                                     # start with an escape char
#ps1_construct_init+="\[\e[0;37m\][\j:\!\[\e[0;37m\]]"       # bash history state
ps1_construct_init+="\[\e[0;36m\] \t \[\e[1;36m\]"          # time
#ps1_construct_init+="\[\e[0;36m\] \d \[\e[1;30m\]"         # date

if [ -z ${IN_NIX_SHELL} ]; then
  ps1_construct_interm_std="\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;32m\]+${SHLVL}\[\e[1;30m\]" # [user@hostname: +shell level]
else
  ps1_construct_interm_clang="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]clang-env\[\e[1;30m\]]" # [user@hostname: clang-env]
  ps1_construct_interm_GNU="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]GNU-env\[\e[1;30m\]]" # [user@hostname: GNU-env]
  ps1_construct_interm_scipy="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]scipy-2.7-env\[\e[1;30m\]]" # [user@hostname: scipy-env]
  ps1_construct_interm_intraday27="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\]\[\e[0;33m\]intraday-2.7-env\[\e[1;30m\]]" # [user@hostname: intraday36-env]
  ps1_construct_interm_stmarket="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\]\[\e[0;33m\]stmarket-3.6-env\[\e[1;30m\]]"  # [user@hostname: stmarket36-env]
  ps1_construct_interm_machlearn="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]machlearn-env\[\e[1;30m\]]" # [user@hostname: machlearn-env]
  ps1_construct_interm_deeproof="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]deeproof-env\[\e[1;30m\]]" # [user@hostname: deeproof-env]
fi

# testing last command line error :
ps1_construct_end="\$(if [[ \$? == 0   ]]; then echo \" \[\033[0;32m\]\342\234\223\"; else echo \" \[\033[01;31m\]\342\234\227\"; fi)"

ps1_construct_end+=" \[\e[1;37m\]\w\[\e[0;37m\]"      # current working directory
ps1_construct_end+=" \n\$ "                           # end with escape and next cmd after $

ps1_std="$ps1_construct_init $ps1_construct_interm_std $ps1_construct_end"
ps1_clang="$ps1_construct_init $ps1_construct_interm_clang $ps1_construct_end"
ps1_GNU="$ps1_construct_init $ps1_construct_interm_GNU $ps1_construct_end"
ps1_scipy="$ps1_construct_init $ps1_construct_interm_scipy $ps1_construct_end"
ps1_intraday27="$ps1_construct_init $ps1_construct_interm_intraday27 $ps1_construct_end"
ps1_stmarket="$ps1_construct_init $ps1_construct_interm_stmarket $ps1_construct_end"
ps1_machlearn="$ps1_construct_init $ps1_construct_interm_machlearn $ps1_construct_end"
ps1_deeproof="$ps1_construct_init $ps1_construct_interm_deeproof $ps1_construct_end"


export PS1=$ps1_std
##################################################}}}

# LS_COLORS settings : {{{
# enable color support of ls and also add handy aliases
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors $waxCraft_PATH/dotfiles/.dircolors`"
    # DONE in .bash_aliases
    #alias ls='ls --color=auto'
    #alias dir='ls --color=auto --format=vertical'
    #alias vdir='ls --color=auto --format=long'
fi
#}}}

# History settings : {{{
##################################################
# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
export HISTIGNORE="ls:cd:clear:[bf]g:history:exit"
export HISTCONTROLE=ignoreboth:erasedups #:ignorespace
export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTFILE=$HOME/.bash_history
export HISTTIMEFORMAT='| %d/%m/%y %T | '    # make 'History' Show The Date For Each Command

# Append to the history file when the shell exits, rather than overwritting the history file
shopt -s histappend
# To append every line to history individually set:
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
#With these two settings, a new shell will get the history lines from all previous
#shells instead of the default 'last window closed'>history

_bash_history_sync() {
  builtin history -a         #1 : append the new history lines to the history file
  HISTFILESIZE=$HISTSIZE     #2
  builtin history -c         #3 : clear the history list
  builtin history -r         #4 : read the current history file and append its
                             #    contents to the history list
}

history() {                  #5
  _bash_history_sync
  builtin history "$@"
}

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
##################################################
#}}}

#Usefull functions : {{{

# function Extract for common file formats
function extract {
 if [ -z "$1" ]; then
    # display usage if no parameters given
    echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
    echo "       extract <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
 else
    for n in $@
    do
      if [ -f "$n" ] ; then
          case "${n%,}" in
            *.tar.bz2|*.tar.gz|*.tar.xz|*.tbz2|*.tgz|*.txz|*.tar)
                         tar xvf "$n"       ;;
            *.lzma)      unlzma ./"$n"      ;;
            *.bz2)       bunzip2 ./"$n"     ;;
            *.rar)       unrar x -ad ./"$n" ;;
            *.gz)        gunzip ./"$n"      ;;
            *.zip)       unzip ./"$n"       ;;
            *.z)         uncompress ./"$n"  ;;
            *.7z|*.arj|*.cab|*.chm|*.deb|*.dmg|*.iso|*.lzh|*.msi|*.rpm|*.udf|*.wim|*.xar)
                         7z x ./"$n"        ;;
            *.xz)        unxz ./"$n"        ;;
            *.exe)       cabextract ./"$n"  ;;
            *)
                         echo "extract: '$n' - unknown archive method"
                         return 1
                         ;;
          esac
      else
          echo "'$n' - file does not exist"
          return 1
      fi
    done
fi
}
#}}}

# better yaourt colors
export YAOURT_COLORS="nb=1:pkg=1:ver=1;32:lver=1;45:installed=1;42:grp=1;34:od=1;41;5:votes=1;44:dsc=0:other=1;35"

export LC_ALL=en_US.utf8
export LANG=en_US.utf8
