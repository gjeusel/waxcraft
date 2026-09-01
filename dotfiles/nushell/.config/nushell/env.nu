$env.WAXPATH = ($env.HOME | path join "src" "waxcraft")

$env.LC_ALL = "en_US.UTF-8"
$env.LANG = "en_US.UTF-8"

$env.EDITOR = "nvim"
$env.GIT_EDITOR = "nvim"
$env.VISUAL = "nvim"

$env.PYTHONSTARTUP = ($env.HOME | path join ".config" "python" "startup.py")
$env.IPYTHONDIR = ($env.HOME | path join ".config" "ipython")
$env.PTPYTHON_CONFIG_HOME = ($env.HOME | path join ".config" "ptpython")

$env.GOPATH = ($env.HOME | path join ".go")
$env.NPM_CONFIG_PREFIX = ($env.HOME | path join ".local")
$env.PNPM_HOME = ($env.HOME | path join "Library" "pnpm")
$env.CONDARC = ($env.HOME | path join ".config" "conda" "condarc")
$env.KUBECONFIG = ($env.HOME | path join ".config" "kube" "config")
$env.KREW_ROOT = ($env.HOME | path join ".config" "krew")
$env.PSQL_HISTORY = ($env.HOME | path join ".cache" "psql_history")

$env.PATH = ([
    ($env.GOPATH | path join "bin")
    ($env.HOME | path join ".cargo" "bin")
    ($env.HOME | path join ".local" "bin")
    ($env.PNPM_HOME | path join "bin")
    $env.PNPM_HOME
    ($env.KREW_ROOT | path join "bin")
] | append $env.PATH | uniq)

$env.BAT_THEME = "gruvbox-dark"
$env.FFF_ENABLE_HOME_SCAN = "0"
$env.FZF_DEFAULT_OPTS = ([
    "--pointer="
    "--color=fg:#e5e9f0,bg+:#3b4252,hl:#81a1c1"
    "--color=fg+:#e5e9f0,bg+:#3b4252,hl+:#81a1c1"
    "--color=info:#eacb8a,prompt:#bf6069,pointer:#b48dac"
    "--color=marker:#a3be8b,spinner:#b48dac,header:#a3be8b"
    "--color=gutter:-1"
] | str join " ")
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git --exclude node_modules --exclude .cache --exclude .venv --exclude .mypy --exclude venv --exclude __pycache__ --exclude '*.pyc' --exclude '*.pyo' --exclude '*.class' --exclude '*.o' --exclude '*.so' --exclude '*.swp' --exclude '*.swo' --exclude '.DS_Store' --exclude '*.log'"
$env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND

$env.HOMEBREW_NO_AUTO_UPDATE = "1"
$env.HOMEBREW_NO_INSTALL_CLEANUP = "1"
$env.HOMEBREW_NO_ENV_HINTS = "1"
$env.DISABLE_AUTO_TITLE = "true"

$env.PYARROW_IGNORE_TIMEZONE = "1"
$env.SCW_DISABLE_CHECK_VERSION = "true"
$env.TURBO_NO_UPDATE_NOTIFIER = "true"
$env.VITE_CJS_IGNORE_WARNING = "true"
$env.ESLINT_USE_FLAT_CONFIG = "true"

$env.PI_SKIP_VERSION_CHECK = "true"
$env.PI_TASKS = $"/tmp/pi-tasks-($env.USER).json"
