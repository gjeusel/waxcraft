$env.config.show_banner = false
$env.config.buffer_editor = "nvim"
$env.config.edit_mode = "emacs"
$env.config.highlight_resolved_externals = true
$env.config.completions.algorithm = "fuzzy"
$env.config.history = {
    file_format: sqlite
    max_size: 100_000
    sync_on_enter: true
    isolation: false
    path: ""
    ignore_space_prefixed: true
}

$env.PROMPT_INDICATOR = "λ "
$env.PROMPT_COMMAND_RIGHT = ""

$env.config.keybindings ++= [{
    name: edit_command_line
    modifier: control
    keycode: char_x
    mode: [emacs vi_insert vi_normal]
    event: { send: OpenEditor }
}]

alias wax = cd $env.WAXPATH
alias vimrc = nvim ($env.WAXPATH | path join "dotfiles" "nvim" ".config" "nvim" "lua" "wax" "plugins.lua")
alias zshrc = nvim ($env.HOME | path join ".zshrc")
alias czshrc = nvim ($env.WAXPATH | path join "zsh" "init.zsh")
alias nurc = nvim $nu.config-path
alias cnurc = nvim ($env.WAXPATH | path join "dotfiles" "nushell" ".config" "nushell" "config.nu")

alias vi = nvim
alias vim = nvim
alias v = nvim
alias vimdiff = nvim -d

alias tf = terraform

alias gl = git pull
alias gp = git push
alias gd = git diff
alias gc = git commit --verbose
alias gco = git checkout
alias gb = git branch
alias gs = git status
alias ga = git add
alias glog = git log --graph --no-merges --abbrev-commit "--pretty=%C(dim red)%h%C(reset) - %s %C(yellow)%d%C(reset) %C(dim green)(%cr) %C(dim blue)<%aN>%C(reset)"

alias dk = docker
alias k = kubectl
alias dco = docker-compose
alias e64 = encode base64
alias d64 = decode base64

# Keep the API key available interactively while preventing Pi's Claude bridge from inheriting it.
def --wrapped pi [...args] {
    with-env { ANTHROPIC_API_KEY: null } {
        ^pi ...$args
    }
}

def --wrapped kdebug [image: string = "busybox", ...command: string] {
    let command = if ($command | is-empty) { ["sh"] } else { $command }
    ^kubectl run -i --rm --tty debug $"--image=($image)" --restart=Never -- ...$command
}

def fuzzy-gco [] {
    let branch = (
        ^git branch --all "--format=%(refname:short)"
        | lines
        | each { str replace --regex '^origin/' '' }
        | uniq
        | str join (char nl)
        | ^fzf
        | str trim
    )

    if not ($branch | is-empty) {
        ^git checkout $branch
    }
}

alias gcos = fuzzy-gco

def fopen [] {
    let file = (^fd --type f --hidden --exclude .git | ^fzf | str trim)
    if not ($file | is-empty) {
        ^open $file
    }
}

def --env unproxy [] {
    hide-env -i http_proxy
    hide-env -i https_proxy
    hide-env -i rsync_proxy
    hide-env -i ftp_proxy
    hide-env -i HTTP_PROXY
    hide-env -i HTTPS_PROXY
}

$env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD?
    | default []
    | append {|_, directory| ^zoxide add -- $directory }
)

def --env --wrapped z [...terms: string] {
    let target = match $terms {
        [] => "~"
        ["-"] => "-"
        [$path] if ($path | path expand | path type) == "dir" => $path
        _ => (^zoxide query --exclude $env.PWD -- ...$terms | str trim)
    }
    cd $target
}

def --env --wrapped zi [...terms: string] {
    let target = (^zoxide query --interactive -- ...$terms | str trim)
    if not ($target | is-empty) {
        cd $target
    }
}
