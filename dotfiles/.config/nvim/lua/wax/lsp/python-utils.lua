local scan = require("plenary.scandir")
local Path = require("plenary.path")
local path = require("lspconfig.util").path

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

M.get_python_path = function(workspace)
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
    local project_name = vim.fn.fnamemodify(Path:new(workspace):absolute(), ":t:r")
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
      return path.join(conda_venv_path[1], "bin", "python")
    end

    -- Check for any virtualenv named like the project
    if Path.new(workspace):joinpath("poetry.lock"):exists() then
      local poetry_venv_path = scan.scan_dir(M.basepath_poetry_venv, opts)
      log.info("project_name", project_name)
      log.info("basepath_poetry_venv: ", M.basepath_poetry_venv)
      log.info("poetry_venv_path: ", poetry_venv_path)
      if #poetry_venv_path >= 1 then
        return path.join(poetry_venv_path[1], "bin", "python")
      end
    end
  end

  -- Fallback to system Python.
  return "python"
end

M.on_new_workspace_python_path = function(new_workspace)
  local python_path = nil

  if string.find(new_workspace, M.basepath_poetry_venv) then
    -- In case of jump to definition inside dependency with poetry venv:
    python_path = path.join(find_root_dir_fn({ "pyvenv.cfg" })(new_workspace), "bin", "python")
  elseif string.find(new_workspace, M.basepath_conda_venv) then
    -- In case of jump to definition inside dependency with conda venv:
    python_path = path.join(find_root_dir_fn({ "conda-meta" })(new_workspace), "bin", "python")
  else
    python_path = M.get_python_path(new_workspace)
  end

  return python_path
end

return M
