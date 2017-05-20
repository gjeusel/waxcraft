# If not running interactively, don't do anything
if [ -z "$PS1"  ]; then return; fi

# To declare waxCraft PATH :
#export waxCraft_PATH="$(cd "$(dirname "$(dirname $(readlink "${HOME}/.bash_aliases"))")" && pwd)"
export waxCraft_PATH="$(cd "$(dirname "$(dirname "$BASH_SOURCE" )")" && pwd)"

# Deactivate ksshaskpass popup
unset SSH_ASKPASS

# To adds a * to the branch name if the branch has been changed
export GIT_PS1_SHOWDIRTYSTATE=1
export EDITOR=vim
export GIT_EDITOR=vim

# Prompt shell setup : {{{
##################################################
ps1_construct_init="\n"                                     # start with an escape char
ps1_construct_init+="\[\e[1;30m\][\j:\!\[\e[1;30m\]]"       # bash history state
ps1_construct_init+="\[\e[0;36m\] \t \[\e[1;30m\]"          # time
#ps1_construct_init+="\[\e[0;36m\] \d \[\e[1;30m\]"         # date

if [ -z ${IN_NIX_SHELL} ]; then
  ps1_construct_interm_std="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;32m\]+${SHLVL}\[\e[1;30m\]]" # [user@hostname: +shell level]
else
  ps1_construct_interm_clang="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]clang-env\[\e[1;30m\]]" # [user@hostname: clang-env]
  ps1_construct_interm_GNU="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]GNU-env\[\e[1;30m\]]" # [user@hostname: GNU-env]
  ps1_construct_interm_scipy="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]scipy-2.7-env\[\e[1;30m\]]" # [user@hostname: scipy-env]
  ps1_construct_interm_machlearn="[\[\e[1;34m\]\u@\H\[\e[1;30m\]:\[\e[0;37m\] \[\e[0;33m\]machlearn-env\[\e[1;30m\]]" # [user@hostname: machlearn-env]
fi

# testing last command line error :
ps1_construct_end="\$(if [[ \$? == 0   ]]; then echo \" \[\033[0;32m\]\342\234\223\"; else echo \" \[\033[01;31m\]\342\234\227\"; fi)"

ps1_construct_end+=" \[\e[1;37m\]\w\[\e[0;37m\]"      # current working directory
ps1_construct_end+=" \n\$ "                           # end with escape and next cmd after $

ps1_std="$ps1_construct_init $ps1_construct_interm_std $ps1_construct_end"
ps1_clang="$ps1_construct_init $ps1_construct_interm_clang $ps1_construct_end"
ps1_GNU="$ps1_construct_init $ps1_construct_interm_GNU $ps1_construct_end"
ps1_scipy="$ps1_construct_init $ps1_construct_interm_scipy $ps1_construct_end"
ps1_machlearn="$ps1_construct_init $ps1_construct_interm_machlearn $ps1_construct_end"


export PS1=$ps1_std
##################################################}}}

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

# Color chart  {{{
##################################################
# Reset
Color_Off='\e[0m'       # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White

##################################################
#}}}
