local Path = require("wax.path")

local M = {}

M.basepath_poetry_venv = Path.home():join("/Library/Caches/pypoetry/virtualenvs")

M.basepath_conda = nil
M.basepath_conda_venv = nil
if vim.env.CONDA_EXE then
  M.basepath_conda = Path:new(vim.env.CONDA_EXE):parent():parent()
  M.basepath_conda_venv = M.basepath_conda:join("envs")
end

local find_python_cmd = wax_cache_fn(function(workspace, cmd)
  -- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107

  -- If conda env is activated, use it
  if vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= M.basepath_conda.filename then
    return Path:new(vim.env.CONDA_PREFIX):join("bin"):join(cmd):absolute()
  end

  -- If virtualenv is activated, use it
  if vim.env.VIRTUAL_ENV then
    return Path:new(vim.env.VIRTUAL_ENV):join("bin"):join(cmd):absolute()
  end

  -- If a conda env exists with `almost` the same name as the workspace, use it
  local workspace_name = to_workspace_name(workspace)
  if workspace and workspace_name then
    local pattern = (".*%s.*"):format(workspace_name)

    -- Check for any conda env named like the project
    local conda_venv_path = M.basepath_conda_venv:glob(pattern)
    if #conda_venv_path > 0 then
      return conda_venv_path[1]:join("bin", cmd):absolute()
    end

    -- Check for any virtualenv named like the project
    if Path:new(workspace):join("poetry.lock"):exists() then
      local poetry_venv_path = M.basepath_poetry_venv:glob(pattern)
      if #poetry_venv_path >= 1 then
        return poetry_venv_path[1]:join("bin", cmd):absolute()
      end
    end
  end

  -- Fallback to system Python.
  return cmd
end)

M.get_python_path = wax_cache_fn(function(workspace, cmd)
  workspace = workspace or find_workspace_name(vim.api.nvim_buf_get_name(0))
  cmd = cmd or "python"

  if workspace == nil then
    return cmd
  end

  local python_path = nil

  local function pattern_to_python_path(pattern)
    return Path:new(workspace):find_root_dir({ pattern }):join("bin", cmd):absolute()
  end

  if string.find(workspace, M.basepath_poetry_venv.path) then
    -- In case of jump to definition inside dependency with poetry venv:
    python_path = pattern_to_python_path("pyvenv.cfg")
  elseif string.find(workspace, M.basepath_conda_venv.path) then
    -- In case of jump to definition inside dependency with conda venv:
    python_path = pattern_to_python_path("conda-meta")
  else
    python_path = find_python_cmd(workspace, cmd)
  end

  return python_path
end)

return M
