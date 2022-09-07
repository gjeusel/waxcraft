local scan = require("plenary.scandir")
local Path = require("plenary.path")
local path = require("lspconfig.util").path

-- local functional = require("nvim-lsp-installer.core.functional")
-- local installer = require("nvim-lsp-installer.core.installer")
-- local settings = require("nvim-lsp-installer.settings")
-- local Optional = require("nvim-lsp-installer.core.optional")

local M = {}

M.find_root_dir = find_root_dir_fn({
  ".git",
  "Dockerfile",
  "pyproject.toml",
  "setup.cfg",
})

M.basepath_poetry_venv = os.getenv("HOME") .. "/Library/Caches/pypoetry/virtualenvs" or ""

if os.getenv("CONDA_EXE") then
  M.basepath_conda_venv = Path
    :new(os.getenv("CONDA_EXE"))
    :parent()
    :parent()
    :joinpath("envs")
    :absolute()
else
  M.basepath_conda_venv = ""
end

M.workspace_to_project = function(workspace)
  local workspace_abs = Path:new(workspace):absolute()
  local project = vim.fn.fnamemodify(workspace_abs, ":t:r")
  if project == "" then
    return nil
  else
    return project
  end
end

local function find_python_cmd(workspace, cmd)
  -- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107

  -- If conda env is activated, use it
  if vim.env.CONDA_PREFIX then
    return path.join(vim.env.CONDA_PREFIX, "bin", cmd)
  end

  -- If virtualenv is activated, use it
  if vim.env.VIRTUAL_ENV then
    return path.join(vim.env.VIRTUAL_ENV, "bin", cmd)
  end

  -- If a conda env exists with the same name as the workspace, use it
  local project_name = M.workspace_to_project(workspace)
  if workspace and project_name then
    local search_pattern_regex = vim.regex(".*" .. project_name .. ".*")
    local opts = {
      depth = 0,
      add_dirs = true,
      search_pattern = function(entry)
        return search_pattern_regex:match_str(entry)
      end,
    }

    -- Check for any conda env named like the project
    local conda_venv_path = scan.scan_dir(M.basepath_conda_venv, opts)
    if #conda_venv_path >= 1 then
      return path.join(conda_venv_path[1], "bin", cmd)
    end

    -- Check for any virtualenv named like the project
    if Path.new(workspace):joinpath("poetry.lock"):exists() then
      local poetry_venv_path = scan.scan_dir(M.basepath_poetry_venv, opts)
      log.info("project_name", project_name)
      log.info("basepath_poetry_venv: ", M.basepath_poetry_venv)
      log.info("poetry_venv_path: ", poetry_venv_path)
      if #poetry_venv_path >= 1 then
        return path.join(poetry_venv_path[1], "bin", cmd)
      end
    end
  end

  -- Fallback to system Python.
  return cmd
  -- return os.getenv("CONDA_PYTHON_EXE")
end

M.get_python_path = function(workspace, cmd)
  workspace = workspace or ""
  cmd = cmd or "python"
  local python_path = nil

  if string.find(workspace, M.basepath_poetry_venv) then
    -- In case of jump to definition inside dependency with poetry venv:
    python_path = path.join(find_root_dir_fn({ "pyvenv.cfg" })(workspace), "bin", cmd)
  elseif string.find(workspace, M.basepath_conda_venv) then
    -- In case of jump to definition inside dependency with conda venv:
    python_path = path.join(find_root_dir_fn({ "conda-meta" })(workspace), "bin", cmd)
  else
    python_path = find_python_cmd(workspace, cmd)
  end

  return python_path
end

-- M.create_installer = function(python_executable, packages)
--   return function()
--     local ctx = installer.context()
--     local pkgs = functional.list_copy(packages)

--     ctx.requested_version:if_present(function(version)
--       pkgs[1] = ("%s==%s"):format(pkgs[1], version)
--     end)

--     Optional.of_nilable(python_executable)
--       :if_present(function()
--         ctx.spawn.python({
--           "-m",
--           "pip",
--           "install",
--           "-U",
--           settings.current.pip.install_args,
--           pkgs,
--         })
--       end)
--       :or_else_throw("Unable to install packages using %s")
--       :format(python_executable)

--     local with_receipt = function()
--       ctx.receipt:with_primary_source(ctx.receipt.pip3(packages[1]))
--       for i = 2, #packages do
--         ctx.receipt:with_secondary_source(ctx.receipt.pip3(packages[i]))
--       end
--     end

--     return with_receipt
--   end
-- end

return M
