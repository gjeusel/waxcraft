-------- Module Operations --------

function is_module_available(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

-------- OS Operations --------

function get_os_command_output(cmd, cwd)
  local telescope_utils = require("telescope.utils")
  return telescope_utils.get_os_command_output(cmd, cwd)
end

function is_git(cwd)
  local cmd = { "git", "rev-parse", "--show-toplevel" }
  local telescope_utils = require("telescope.utils")
  local git_root, ret = get_os_command_output(cmd, cwd)
  if ret ~= 0 or #git_root <= 0 then
    return false
  else
    return true
  end
end

function find_root_dir_fn()
  lspconfig = require("lspconfig")
  return lspconfig.util.root_pattern(
    ".git",
    "Dockerfile",
    "pyproject.toml",
    "setup.cfg",
    "package.json",
    "tsconfig.json"
  )
end

function find_root_dir(path)
  return find_root_dir_fn()(path)
end

-------- Debug utils --------

function dump(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
  print(unpack(objects))
end

-------- Mapping to other plugins entire modules --------

if is_module_available("lspconfig/util") then
  local lspconfig_util = require("lspconfig/util")
  path = lspconfig_util.path
else
  -- TODO: mock it
  file = ""
end

local known_colorschemes = { "gruvbox", "nord" }
if vim.tbl_contains(known_colorschemes, os.getenv("ITERM_PROFILE")) then
  iterm_colorscheme = os.getenv("ITERM_PROFILE")
else
  iterm_colorscheme = "default"
end
