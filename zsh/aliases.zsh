# Own config
alias wax="cd $WAXPATH"
alias vimrc="vim $WAXPATH/dotfiles/nvim/.config/nvim/lua/wax/plugins.lua"
alias zshrc="vim ${ZDOTDIR:-$HOME}/.zshrc"
alias czshrc="vim $WAXPATH/zsh/init.zsh"

# definitly swhich to nvim:
alias vi="nvim"
alias vim="nvim"
alias v="nvim"
alias vimdiff="nvim -d"

# Terraform
alias tf="terraform"

# git
alias gl='git pull'
alias gp='git push'
alias gd='git diff'
alias gc='git commit --verbose'
alias gco='git checkout'
alias gb='git branch'
alias gs='git status'
alias ga='git add'
alias glog="git log --graph --no-merges --abbrev-commit --pretty='%C(dim red)%h%C(reset) - %s %C(yellow)%d%C(reset) %C(dim green)(%cr) %C(dim blue)<%aN>%C(reset)'"

# ls colorized output
alias ls='ls -G'

# Docker & Kubernetes
alias dk="docker"
alias k=kubectl
alias dco="docker-compose"

kdebug() {
  kubectl run -i --rm --tty debug --image=${1:-busybox} --restart=Never -- ${2:-sh}
}

kvdebug() {
  if [ $# -eq 0 ]; then
      echo "Run a debug pods with mounted volume in /volume"
      echo "> kvdebug <image> <claimName>"
      return
  fi

  sanename=debug-`echo $1 | sed s:\/:\-:g`

  k run -i --tty --rm $sanename \
  --image=$1 --restart=Never \
  --overrides='
  {
    "apiVersion": "v1",
    "spec": {
      "containers": [
        {
          "image": "'${1}'",
          "name": "'${sanename}'",
          "command": ["/bin/sh"],
          "stdin": true,
          "stdinOnce": true,
          "tty": true,
          "volumeMounts": [
            {
              "mountPath": "/volume",
              "name": "my-volume"
            }
          ]
        }
      ],
      "volumes": [
        {
          "name": "my-volume",
          "persistentVolumeClaim": {
            "claimName": "'${2}'"
          }
        }
      ]
    }
  }
  ' -- sh
}

function fuzzy_gco() {
  branch=`git branch -a| fzf`
  pattern_to_exclude="remotes/origin/"
  local_branch=`echo "$branch"| sed "s:$pattern_to_exclude::"`
  git checkout `echo $local_branch`
}
alias gcos=fuzzy_gco

# Proxy
function unproxy() {
  unset http_proxy https_proxy rsync_proxy ftp_proxy HTTP_PROXY HTTPS_PROXY
}
alias negociate_proxy='curl --proxy-negotiate -I -u :  http://google.com'

# Python / Conda
alias act='conda deactivate && conda activate'
alias deact='conda deactivate'
alias lsp_python_deps='pip install -U ruff "python-lsp-server[rope]" jedi pylsp-mypy'

# Fuzzy finders
vag() {
  regex=${1}
  files=$(ag --recurse --files-with-matches $regex)

  if [ $files ]; then
    $EDITOR +/"$regex" $(echo $files)
  else;
    echo "$regex not found in any file here."
  fi;
}

vfzf() {
  _match_fzf="$(fzf --preview '[[ $(file --mime {}) =~ binary ]] &&
    echo {} is a binary file ||
    (bat --style=numbers --color=always {} ||
    highlight -O ansi -l {} ||
    coderay {} ||
    rougify {} ||
    cat {}) 2> /dev/null | head -500')"

  if [ -n "$_match_fzf" ]; then
    nvim "$_match_fzf"
  fi
}

alias vfind='nvim $(find . -path ".*$*")'

# Bind ctrl + p  to fuzzy finder
# -s simulate keyboard entry
# (^U) to delete the whole line
# type fzf
# (^M) to execute the line
#bindkey -s "^P" "^Uvfzf^M"

# To get tmux navigation accross root panes
#https://www.bountysource.com/issues/33111484-problems-with-sudo-vim
alias sudo='sudo TMUX="${TMUX}" '

# move to trash instead of rm
function del() {
    mv $* ~/.Trash
}

# alias to get resilient shit
function resilient() {
  while true; do $* && break; done
}

# alias to launch Brave
alias brave="/Applications/Brave\ Browser.app/Contents/MacOS/Brave\ Browser"

# helper dst
function dst() {
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color

  echo -e "year --> $YELLOW winter-summer $NC - $BLUE summer-winter $NC"
  echo -e "       (+01:00 -> +02:00) (+02:00 -> +01:00)"
  echo -e "--------------------------------------------"
  echo -e "2015 -->    $YELLOW 29/03 $NC      -      $BLUE 25/10 $NC"
  echo -e "2016 -->    $YELLOW 27/03 $NC      -      $BLUE 30/10 $NC"
  echo -e "2017 -->    $YELLOW 26/03 $NC      -      $BLUE 29/10 $NC"
  echo -e "2018 -->    $YELLOW 25/03 $NC      -      $BLUE 28/10 $NC"
  echo -e "2019 -->    $YELLOW 31/03 $NC      -      $BLUE 27/10 $NC"
  echo -e "2020 -->    $YELLOW 29/03 $NC      -      $BLUE 25/10 $NC"
  echo -e "2021 -->    $YELLOW 28/03 $NC      -      $BLUE 31/10 $NC"
  echo -e "2022 -->    $YELLOW 27/03 $NC      -      $BLUE 30/10 $NC"
  echo -e "2023 -->    $YELLOW 26/03 $NC      -      $BLUE 29/10 $NC"
  echo -e "                        ---"
  echo -e "2024 -->    $YELLOW 31/03 $NC      -      $BLUE 27/10 $NC"
  echo -e "2025 -->    $YELLOW 30/03 $NC      -      $BLUE 26/10 $NC"
  echo -e "2026 -->    $YELLOW 29/03 $NC      -      $BLUE 25/10 $NC"
}

encode64() {
    if [[ $# -eq 0 ]]; then
        cat | base64
    else
        printf '%s' $1 | base64
    fi
}

decode64() {
    if [[ $# -eq 0 ]]; then
        cat | base64 --decode
    else
        printf '%s' $1 | base64 --decode
    fi
}
alias e64=encode64
alias d64=decode64

function generate_fernet_key() {
  # https://stackoverflow.com/questions/44432945/generating-own-key-with-python-fernet
  dd if=/dev/urandom bs=32 count=1 2>/dev/null | openssl base64
}

function realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

function webp2gitlab() {
  # function to convert a webp created by chatgpt into png for gitlab icon
  local input_webp="$1"
  local output_png="$2"

  sips -s format png "$input_webp" --out "$output_png"
  sips -z 192 192 "$output_png"
}
