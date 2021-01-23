_CUSTOM_WORDCHARS='*?_[]~=&;!#$%^(){}<>'

# backward and forward word with option+left/right
tcsh-backward-word () {
  local WORDCHARS=_CUSTOM_WORDCHARS
  zle backward-word
}
zle -N tcsh-backward-word
bindkey '^[b' tcsh-backward-word
tcsh-forward-word () {
  local WORDCHARS=_CUSTOM_WORDCHARS
  zle forward-word
}
zle -N tcsh-forward-word
bindkey '^[f' tcsh-forward-word

# backward and forward word with ctrl+left/right
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# https://superuser.com/questions/1421423/how-to-bind-option-delete-to-backward-delete-word-in-zsh-vi-mode-in-tmux-and-ala
# Ensure having same behaviour in tmux
bindkey '^W' backward-kill-word

# Delete word with option+backspace with more word delimiters
# https://www.zsh.org/mla/users/2001/msg00870.html
tcsh-backward-delete-word () {
  local WORDCHARS=_CUSTOM_WORDCHARS
  zle backward-delete-word
}
zle -N tcsh-backward-delete-word
bindkey '^[^H' tcsh-backward-delete-word

# delete char
bindkey "^[[3~" delete-char

# beginning / end of line
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# edit command line in $EDITOR
bindkey '^X' edit-command-line

# Hist search
bindkey '^r' history-incremental-search-backward
bindkey '^R' history-incremental-pattern-search-backward

# Hist search completion of line with arrows up and down using ohmyzsh history-substring-search
bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down

# Bind ctrl + space
bindkey '^ ' autosuggest-accept
