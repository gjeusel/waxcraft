local python_utils = require("wax.lsp.python-utils")
local Pkg = require("mason-core.package")

local mason_pip = require("mason-core.managers.pip3")
local mason_index = require("mason-registry.index")

local lspname = "dmypyls"

-- register new server in lspconfig
require("lspconfig.configs")[lspname] = {
  default_config = {
    cmd = { "dmypy-ls" },
    filetypes = { "python" },
    root_dir = lspconfig.util.root_pattern(
      "pyproject.toml",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      "Pipfile"
    ),
    single_file_support = true,
  },
}

local function to_dmypyls_cmd(python_path)
  -- python -c "from dmypy_ls import main; main()" --help
  local cmd = { python_path, "-c", "from dmypy_ls import main; main()" }

  if waxopts.lsp.loglevel == "debug" then
    vim.list_extend(cmd, { "--debug" })
  end
  return cmd
end

local function register_dmypyls(python_path, project)
  project = project or "default"

  local msg = "LSP python (dmypyls) - '%s' using path %s"
  log.info(msg:format(project, python_path))

  mason_index[lspname] = Pkg.new({
    name = lspname,
    desc = [[Daemon Mypy LSP for faster type checking in python.]],
    homepage = "https://github.com/sileht/dmypy-ls",
    languages = { Pkg.Lang.Python },
    categories = { Pkg.Cat.LSP },
    install = mason_pip.packages("dmypy-ls", { bin = to_dmypyls_cmd(python_path) }),
  })
end

-- init nvim-lsp-installer with CWD at first
local initial_workspace = find_root_dir(".")
register_dmypyls(
  python_utils.get_python_path(initial_workspace, "python"),
  python_utils.workspace_to_project(initial_workspace)
)

return {
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace, "python")

    local msg = "LSP python (dmypyls) - '%s' using path %s"
    log.info(msg:format(python_utils.workspace_to_project(new_workspace), python_path))

    if python_path == "python" then
      msg = "LSP python (dmypyls) - keeping previous python path '%s' for new_root_dir '%s'"
      log.info(msg:format(config.cmd[1], new_workspace))
      return config
    end

    msg = "LSP python (dmypyls) - new path '%s' for new_root_dir '%s'"
    log.info(msg:format(python_path, new_workspace))

    -- Update nvim-lsp-installer dmypyls server by re-creating it
    local project = python_utils.workspace_to_project(new_workspace)
    register_dmypyls(python_path, project)
    local cmd = to_dmypyls_cmd(python_path)
    config.cmd = cmd
    return config
  end,
}
