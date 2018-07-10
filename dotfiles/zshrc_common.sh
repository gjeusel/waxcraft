# Source aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# To declare waxCraft PATH :
export waxCraft_PATH="$(cd "$(dirname "$(dirname "$BASH_SOURCE" )")" && pwd)"

# Deactivate ksshaskpass popup
unset SSH_ASKPASS

# Visual for yaourt help at fail:
export VISUAL="vim"

# better yaourt colors
export YAOURT_COLORS="nb=1:pkg=1:ver=1;32:lver=1;45:installed=1;42:grp=1;34:od=1;41;5:votes=1;44:dsc=0:other=1;35"

export LC_ALL=en_US.utf8
export LANG=en_US.utf8
