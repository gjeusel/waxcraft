local Path = require("wax.path")

local M = {}

M.basepath_conda = nil
M.basepath_conda_venv = nil
if vim.env.CONDA_EXE then
  M.basepath_conda = Path:new(vim.env.CONDA_EXE):parent():parent()
  M.basepath_conda_venv = M.basepath_conda:join("envs")
end
if vim.env.MAMBA_ROOT_PREFIX then
  M.basepath_conda = Path:new(vim.env.MAMBA_ROOT_PREFIX)
  M.basepath_conda_venv = M.basepath_conda:join("envs")
end

---Return the nearest `.venv` directory, searching from `path` up to its repository root. In a
---monorepo (e.g. a uv workspace), members share the `.venv` living at the repository root.
---@param path string directory to start the search from
---@return string?
function M.find_venv(path)
  local dir = vim.fs.normalize(path)
  local root_repo = find_root_monorepo(dir)
  root_repo = root_repo and vim.fs.normalize(root_repo)

  while true do
    local venv = vim.fs.joinpath(dir, ".venv")
    if vim.fn.isdirectory(venv) == 1 then
      return venv
    end

    -- Outside a repository, only `path` itself is searched.
    local parent = vim.fs.dirname(dir)
    if root_repo == nil or dir == root_repo or parent == dir then
      return nil
    end

    dir = parent
  end
end

M.find_python_cmd = wax_cache_buf_fn(function(workspace, cmd)
  -- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107

  -- If conda env is activated, use it (unless it is the conda base env)
  if
    vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= (M.basepath_conda and M.basepath_conda.path)
  then
    return Path:new(vim.env.CONDA_PREFIX):join("bin"):join(cmd):absolute()
  end

  -- If virtualenv is activated, use it
  if vim.env.VIRTUAL_ENV then
    return Path:new(vim.env.VIRTUAL_ENV):join("bin"):join(cmd):absolute()
  end

  -- If .venv directory, in the package or up to the monorepo root, use it
  local root_package = find_root_package()
  local venv = root_package and M.find_venv(root_package)
  if venv then
    local venv_cmdpath = Path:new(venv):join("bin", cmd)
    if venv_cmdpath:exists() then
      return venv_cmdpath:absolute()
    end
  end

  -- If a conda env exists with `almost` the same name as the workspace, use it
  local workspace_name = to_workspace_name(workspace)
  if workspace and workspace_name then
    -- Check for any conda env named like the project
    if M.basepath_conda_venv then
      local conda_venv_path = M.basepath_conda_venv:glob(workspace_name)
      if #conda_venv_path > 0 then
        return conda_venv_path[1]:join("bin", cmd):absolute()
      end
    end

    -- Check for any virtualenv named like the project
  end

  -- Fallback to system cmd.
  return cmd
end)

M.get_python_path = wax_cache_buf_fn(function(workspace, cmd)
  workspace = workspace or find_workspace_name(vim.api.nvim_buf_get_name(0))
  cmd = cmd or "python"

  if workspace == nil then
    return cmd
  end

  local python_path = nil

  local function pattern_to_python_path(pattern)
    local root = Path:new(workspace):find_root_dir({ pattern })
    if root == nil then
      return nil
    end
    return root:join("bin", cmd):absolute()
  end

  if M.basepath_conda_venv and string.find(workspace, M.basepath_conda_venv.path) then
    -- In case of jump to definition inside dependency with conda venv:
    python_path = pattern_to_python_path("conda-meta") or M.find_python_cmd(workspace, cmd)
  else
    python_path = M.find_python_cmd(workspace, cmd)
  end

  return python_path
end)

return M
