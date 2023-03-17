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
    root_dir = find_root_dir_fn({
      "pyproject.toml",
      "setup.py",
      "setup.cfg",
      "requirements.txt",
      "Pipfile",
    }),
    single_file_support = true,
  },
}

local function to_dmypyls_cmd(python_path)
  -- python -c "from dmypy_ls import main; main()" --help
  local cmd = { python_path, "-c", "from dmypy_ls import main; main()" }

  if waxopts.loglevel == "debug" then
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
  to_workspace_name(initial_workspace)
)

return {
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace, "python")
    local new_workspace_name = to_workspace_name(new_workspace)

    if python_path == "python" then
      local msg = "LSP python (dmypyls) - keeping previous python path '%s' for new_root_dir '%s'"
      log.debug(msg:format(config.cmd[1], new_workspace))
      return config
    else
      local msg = "LSP python (dmypyls) - '%s' using path %s"
      log.info(msg:format(new_workspace_name, python_path))

      register_dmypyls(python_path, new_workspace_name) -- Update mason dmypyls server
      config.cmd = to_dmypyls_cmd(python_path)
      return config
    end
  end,
}
