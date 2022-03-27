local Path = require("plenary.path")

-- Strategy:
--   1. use poetry if available for project
--   2. use conda env activated (if not "base")
--   3. use conda env matching project name
--   4. fallback to "python"

local poetry = nil
if vim.fn.exepath("poetry") ~= "" then
  local bin = Path:new(vim.fn.resolve(vim.fn.exepath("poetry")))

  -- TODO: find a better way ? `poetry run which python` is slow
  local venv = Path:new(os.getenv("HOME")):joinpath("/Library/Caches/pypoetry/virtualenvs")
  poetry = { bin = bin, venv = venv }
end

local conda = nil
if os.getenv("CONDA_EXE") then
  local venv = Path:new(os.getenv("CONDA_EXE")):parent():parent():joinpath("envs")
  conda = { bin = os.getenv("CONDA_EXE"), venv = venv }
end

local opts = { poetry = poetry, conda = conda }


-- TODO: finish it from getting logic from python-utils

local find_root_dir = find_root_dir_fn({
  ".git",
  "Dockerfile",
  "pyproject.toml",
  "setup.cfg",
})

return {
  find_root_dir = find_root_dir,
}
