local scan = require("plenary.scandir")
local Path = require("plenary.path")
local path = require("lspconfig.util").path

local M = {}

M.basepath_poetry_venv = os.getenv("HOME") .. "/Library/Caches/pypoetry/virtualenvs" or ""

if os.getenv("CONDA_EXE") then
  M.basepath_conda_venv =
    Path:new(os.getenv("CONDA_EXE")):parent():parent():joinpath("envs"):absolute()
else
  M.basepath_conda_venv = ""
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
  local workspace_name = to_workspace_name(workspace)
  if workspace and workspace_name then
    local search_pattern_regex = vim.regex(".*" .. workspace_name .. ".*")
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
      if #poetry_venv_path >= 1 then
        return path.join(poetry_venv_path[1], "bin", cmd)
      end
    end
  end

  -- Fallback to system Python.
  return cmd
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

return M
