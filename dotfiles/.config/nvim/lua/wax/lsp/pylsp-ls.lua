local lspconfig_util = require("lspconfig.util")
local path = lspconfig_util.path
local scan = require("plenary.scandir")
local Path = require("plenary.path")

local pyls_config = require("lspinstall/util").extract_config("pylsp")

local find_root_dir = find_root_dir_fn({
  ".git",
  "Dockerfile",
  "pyproject.toml",
  "setup.cfg",
})

local basepath_poetry_venv = os.getenv("HOME") .. "/Library/Caches/pypoetry/virtualenvs"
local basepath_conda_venv = os.getenv("HOME") .. "/opt/miniconda3/envs"

local function get_python_path(workspace)
  -- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107

  -- If conda env is activated, use it
  if vim.env.CONDA_PREFIX then
    return path.join(vim.env.CONDA_PREFIX, "bin", "python")
  end

  -- If virtualenv is activated, use it
  if vim.env.VIRTUAL_ENV then
    return path.join(vim.env.VIRTUAL_ENV, "bin", "python")
  end

  -- If a conda env exists with the same name as the workspace, use it
  if workspace then
    local project_name = vim.fn.fnamemodify(workspace, ":t:r")
    local opts = { depth = 0, add_dirs = true, search_pattern = project_name }
    if Path.new(workspace):joinpath("poetry.lock"):exists() then
      local poetry_venv_path = scan.scan_dir(basepath_poetry_venv, opts)
      if #poetry_venv_path >= 1 then
        return path.join(poetry_venv_path[1], "bin", "python")
      end
    end

    local conda_venv_path = scan.scan_dir(basepath_conda_venv, opts)
    if #conda_venv_path >= 1 then
      return path.join(conda_venv_path[1], "bin", "python")
    end
  end

  -- Fallback to system Python.
  return "python"
end

local to_install = {
  "'python-lsp-server[rope]'", -- lsp
  "pyls-flake8", -- plugin for flake8
  -- 'flake8==3.9.2', 'flake8-bugbear==21.4.3', 'flake8-builtins==1.5.3',
  "pylsp-mypy-rnx", -- plugin for mypy | do not use 'mypy-ls' the official
  -- 'mypy==0.902',
  "python-lsp-black", -- plugin for black
  -- 'black==21.6b0',
  "pyls-isort", -- plugin for isort
  -- 'isort==5.7.0',
}

local log_file = vim.env.HOME .. "/.cache/nvim/pylsp.log"
local log_level = "-v" -- number of v is the level

local function set_lspinstall_pylsp(python_path)
  local install_script = python_path .. " -m pip install"
  local uninstall_script = python_path .. " -m pip uninstall --yes"
  for _, dep in ipairs(to_install) do
    install_script = install_script .. " " .. dep
    uninstall_script = uninstall_script .. " " .. dep
  end

  -- default python_path is the one deduced from CWD at vim startup
  local cmd = { python_path, "-m", "pylsp", "--log-file", log_file, log_level }

  -- Make sure to use 'lspinstall/servers' in requires as its changes the behavior.
  -- If "lspinstall.servers" was used, the variable 'servers' in the module won't be updated.
  -- TODO: investigate why the fuck ?
  require("lspinstall/servers")["pylsp"] = vim.tbl_deep_extend("force", pyls_config, {
    default_config = { cmd = cmd },
    filetypes = { "python", "pyrex" },
    install_script = install_script,
    uninstall_script = uninstall_script,
  })
end

-- init lspinstall with CWD at first
set_lspinstall_pylsp(get_python_path(find_root_dir(".")))

return {
  -- init_options = {documentFormatting = false}, -- if python format by efm
  settings = {
    pylsp = {
      plugins = {
        flake8 = { enabled = true },
        ["pylsp_black"] = { enabled = true },
        ["pyls_isort"] = { enabled = true },
        pylsp_mypy_rnx = {
          enabled = true,
          live_mode = true,
          dmypy = false, -- prevent having live update (only on save)
          -- dmypy_args = {
          --   "--status-file",
          --   "/tmp/dmypy.json",
          -- },
          dmypy_run_args = {
            "--log-file",
            "/tmp/dmypy.log",
            "--verbose",
          },
          -- args = { "--sqlite-cache", "--ignore-missing-imports" },
          args = { "--sqlite-cache" },
        },
      },
    },
  },
  on_new_config = function(config, new_workspace)
    local python_path = nil

    if string.find(new_workspace, basepath_poetry_venv) then
      -- In case of jump to definition inside dependency with poetry venv:
      python_path = path.join(find_root_dir_fn({ "pyvenv.cfg" })(new_workspace), "bin", "python")
    elseif string.find(new_workspace, basepath_conda_venv) then
      -- In case of jump to definition inside dependency with conda venv:
      python_path = path.join(find_root_dir_fn({ "conda-meta" })(new_workspace), "bin", "python")
    else
      python_path = get_python_path(new_workspace)
    end

    if python_path == "python" then
      local new_root_dir_path = Path.new(new_workspace)
      log.info(
        string.format(
          "LSP python - keeping previous python path '%s' for new_root_dir '%s'",
          config.cmd[1],
          new_workspace
        )
      )
      return config
    end

    log.info(
      string.format("LSP python - new path '%s' for new_root_dir '%s'", python_path, new_workspace)
    )
    set_lspinstall_pylsp(python_path)
    config.cmd = { python_path, "-m", "pylsp", "--log-file", log_file, log_level }
  end,
}
