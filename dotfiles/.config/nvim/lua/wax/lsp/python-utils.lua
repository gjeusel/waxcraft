local scan = require("plenary.scandir")
local Path = require("plenary.path")

local M = {}

M.basepath_poetry_venv = os.getenv("HOME") .. "/Library/Caches/pypoetry/virtualenvs" or ""

M.basepath_conda = nil
M.basepath_conda_venv = nil
if vim.env.CONDA_EXE then
  M.basepath_conda = Path:new(vim.env.CONDA_EXE):parent():parent()
  M.basepath_conda_venv = M.basepath_conda:joinpath("envs"):absolute()
end

local find_python_cmd = wax_cache_fn(function(workspace, cmd)
  -- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107

  -- If conda env is activated, use it
  if vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= M.basepath_conda.filename then
    return Path:new(vim.env.CONDA_PREFIX):joinpath("bin"):joinpath(cmd):absolute()
  end

  -- If virtualenv is activated, use it
  if vim.env.VIRTUAL_ENV then
    return Path:new(vim.env.VIRTUAL_ENV):joinpath("bin"):joinpath(cmd):absolute()
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
      return Path:new(conda_venv_path[1]):joinpath("bin"):joinpath(cmd):absolute()
    end

    -- Check for any virtualenv named like the project
    if Path.new(workspace):joinpath("poetry.lock"):exists() then
      local poetry_venv_path = scan.scan_dir(M.basepath_poetry_venv, opts)
      if #poetry_venv_path >= 1 then
        return Path:new(poetry_venv_path[1]):joinpath("bin"):joinpath(cmd):absolute()
      end
    end
  end

  -- Fallback to system Python.
  return cmd
end)

function M.get_python_path(workspace, cmd)
  workspace = workspace or find_workspace_name(vim.api.nvim_buf_get_name(0))
  cmd = cmd or "python"

  if workspace == nil then
    return cmd
  end

  local python_path = nil

  if string.find(workspace, M.basepath_poetry_venv) then
    -- In case of jump to definition inside dependency with poetry venv:
    python_path = Path:new(find_root_dir_fn({ "pyvenv.cfg" })(workspace))
      :joinpath("bin")
      :joinpath(cmd)
      :absolute()
  elseif string.find(workspace, M.basepath_conda_venv) then
    -- In case of jump to definition inside dependency with conda venv:
    python_path = Path:new(find_root_dir_fn({ "conda-meta" })(workspace))
      :joinpath("bin")
      :joinpath(cmd)
      :absolute()
  else
    python_path = find_python_cmd(workspace, cmd)
  end

  return python_path
end

return M
