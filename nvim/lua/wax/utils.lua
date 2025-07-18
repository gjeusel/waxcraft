-------- Register Scratchpad --------

local scratch = require("wax.scratch")

-------- Register Path --------

local Path = require("wax.path")

-------- Debug utils --------

---Open a scratch window with given content
---@param content any
---@return nil
local function open_scratch_win(content)
  local floatopts = scratch.float_win()
  local bufnr = floatopts.bufnr

  -- format content
  local function sanitize_input(e)
    if type(e) == "string" then
      return e
    else
      return vim.inspect(e)
    end
  end

  content = vim.tbl_map(sanitize_input, content)

  local function split_line_return(entry)
    return vim.fn.split(entry, "\\n")
  end

  content = vim.tbl_map(split_line_return, content)
  content = vim.tbl_flatten(content)
  -- content = vim.flatten(content) -- but is null the fucker !

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, content)
end

---Dump the args in vim messages
---@param ... unknown
---@return nil
function _G.dump(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
  print(unpack(objects))
end

---Dump the args inside a floating window scratch buffer
---@param ... unknown
---@return nil
function _G.dumpf(...)
  local content = vim.tbl_map(vim.inspect, { ... })
  open_scratch_win(content)
end

-------- Mocks --------

---Generate a mock
---@param opts table<string, any>
---@return any
function _G.mock(opts)
  local Mock = opts or {}
  setmetatable(Mock, {
    __call = function(...) ---@diagnostic disable-line:unused-vararg
      log.trace(("called __call with args=%s"):format(...))
      return Mock
    end,
    __index = function(...) ---@diagnostic disable-line:unused-vararg
      log.trace(("called __index with args=%s"):format(...))
      return Mock
    end,
  })
  return Mock
end

-------- Module Operations --------

---Return truthy if module is available
---@param name string
---@return boolean
function _G.is_module_available(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

---Try to require. If module is not available, returns a mock.
---@param name string
---@return any
function _G.safe_require(name)
  local res, mod = pcall(require, name)
  if not res then
    log.error(mod)
    return mock()
  else
    return mod
  end
end

-------- FilePaths --------

-- debug.getinfo to get the filepath of the current lua script
-- then get its parent directory

---@type Wax.Path
_G.lua_waxdir = Path:new(vim.fn.fnamemodify(debug.getinfo(1, "S").short_src, ":p:h")) -- "$HOME/.config/nvim/lua/wax"

-------- Cache --------
---@generic T : function
---@param fn T
---@return T
function _G.wax_cache_fn(fn)
  _G._wax_cache = _G._wax_cache or {}

  local function to_cache_key(...)
    local mem_address = string.gsub(tostring(fn), "function: ", "")

    local args = vim
      .iter({ ... })
      :filter(function(e)
        return e ~= nil and e ~= ""
      end)
      :map(tostring)
      :totable()

    local pieces = { mem_address }
    if #args > 0 then
      table.insert(pieces, table.concat(args, ", "))
    end

    return table.concat(pieces, " | ")
  end

  local function wrap(...)
    if select("#", ...) == 0 then
      log.trace("Could not cache call due to empty args.")
      return fn(...)
    end

    local key = to_cache_key(...)
    local value = vim.tbl_get(_G._wax_cache, key)

    if value == nil then
      _G._wax_cache[key] = fn(...)
      log.trace("Cached returned value using cache key", key)
    else
      log.trace("Found in cache using cache key", key)
    end

    return _G._wax_cache[key]
  end

  return wrap
end

-------- Logs --------

_G.log = require("wax.logs").new({
  plugin = "wax",
  level = waxopts.loglevel,
  use_console = false,
})

-------- WorkSpace --------

---Get stringified result of sh command
---@param cmd string[] command to run
---@param cwd? string current working directory
---@return string[] stdout
---@return number command status
---@return string[] stderr
function _G.get_os_command_output(cmd, cwd)
  if type(cmd) ~= "table" then
    return {}, 0, {}
  end

  cwd = cwd or vim.loop.cwd()
  local Job = require("plenary.job")

  local command = table.remove(cmd, 1)
  local stderr = {}
  local stdout, ret = Job:new({
    command = command,
    args = cmd,
    cwd = cwd,
    interactive = false,
    on_stderr = function(_, data)
      table.insert(stderr, data)
    end,
  }):sync()
  return stdout, ret, stderr
end

_G.is_git = wax_cache_fn(
  ---Check if cwd is git versioned
  ---@param cwd string | nil
  ---@return boolean
  function(cwd)
    cwd = cwd or vim.loop.cwd()

    -- local cmd = { "git", "rev-parse", "--show-toplevel" }
    -- local git_root, ret = _G.get_os_command_output(cmd, cwd)
    -- return not (ret ~= 0 or #git_root <= 0)

    local cmd = string.format("git -C %q rev-parse --is-inside-work-tree", cwd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    local result = handle and handle:read("*a")
    if handle then
      handle:close()
    end
    return result and result:match("true") ~= nil
  end
)

_G.find_root_dir = wax_cache_fn(
  ---Return the root directory
  ---@param path string | nil
  ---@param patterns string[] | nil
  ---@return string | nil
  function(path, patterns)
    -- Special case, handling python deps:
    if string.find(path, "site%-packages") then
      local start_pos = string.find(path, "site%-packages")

      -- Get everything up to "site-packages" plus the next component
      local parts = vim.split(path:sub(1, start_pos - 1), "/", { plain = true })
      local package_name = vim.split(path:sub(start_pos), "/", { plain = true })[2]

      -- Reconstruct the path
      local python_pkg_path = table.concat(parts, "/") .. "site-packages/" .. package_name
      return python_pkg_path
    end

    -- Special case, neovim plugin:
    -- /Users/gjeusel/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/providers/grep.lua
    local plugin_base = vim.env.HOME .. "/.local/share/nvim/lazy/"
    if string.find(path, plugin_base, 1, true) then -- true for plain text search
      local remainder = path:sub(#plugin_base + 1)
      local plugin_name = vim.split(remainder, "/", { plain = true })[1]
      return plugin_base .. plugin_name .. "/"
    end

    local default_patterns = { ".git" }
    patterns = patterns or default_patterns
    path = path or vim.loop.cwd()

    local root_dir = Path:new(path):find_root_dir(patterns)
    if root_dir ~= nil then
      return root_dir.path
    else
      return nil
    end
  end
)

---Return the root of a monorepo setup
---@param path string | nil
---@return string | nil
_G.find_root_monorepo = function(path)
  path = path or vim.loop.cwd()
  return _G.find_root_dir(path, { ".git" })
end

---Return the root of a package
---@param path string | nil
---@return string | nil
_G.find_root_package = function(path)
  path = path or vim.loop.cwd()
  return _G.find_root_dir(path, { "package.json", "pyproject.toml" })
end

_G.is_monorepo = wax_cache_fn(
  ---Return the root directory
  ---@param cwd string | nil
  ---@return string | nil
  function(cwd)
    -- cwd = cwd or vim.loop.cwd()
    local root_dir = _G.find_root_monorepo(nil)
    local root_subproject = _G.find_root_package(nil)
    local is_monorepo = root_dir and root_subproject and root_dir ~= root_subproject
    return is_monorepo
  end
)

---Convert the path of the workspace to its name
---@param path string
---@return string?
function _G.to_workspace_name(path)
  return vim.fn.fnamemodify(path, ":t:r") or nil
end

---Return the name of the workspace from a path
---@param path string
---@return string?
function _G.find_workspace_name(path)
  local root_dir = find_root_dir(path or vim.api.nvim_buf_get_name(0))
  if root_dir == nil then
    return nil
  end
  return to_workspace_name(root_dir)
end

-------- Utilities --------

---Check if the bufnr should be considered a big file
---@param fpath string
---@return boolean
function _G.is_big_file(fpath)
  local byte_size = vim.fn.getfsize(fpath)

  if byte_size == 0 then
    log.debug(("Path given is a directory: "):format(fpath))
    return false
  elseif byte_size == -1 then
    log.debug(("Could not find file with path being: %s"):format(fpath))
    return false
  elseif byte_size == -2 then
    return true -- size too big to fit in a Number
  else
    return byte_size > waxopts.big_file_threshold
  end
end

local M = {}

function M.insert_new_line_in_current_buffer(str, opts)
  local bufnr = 0 -- current buffer
  local default_opts = { delta = 1 }
  opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

  local pos = vim.api.nvim_win_get_cursor(bufnr)
  local n_line = pos[1]

  local n_insert_line = n_line + opts.delta

  -- deduce indent for line:
  local n_space = vim.fn.indent(n_line)

  -- special cases depending on filetype
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  if filetype == "python" then
    n_space = vim.fn.GetPythonPEPIndent(n_insert_line)
    if n_space == -1 then -- but fix it when can't find
      n_space = vim.fn.indent(n_line)
    end
  else
    -- if treesitter available, might use it to correct corner cases:
    local has_treesitter = is_module_available("nvim-treesitter.indent")
    if has_treesitter then
      local ts_indent = require("nvim-treesitter.indent")
      n_space = ts_indent.get_indent(n_insert_line)
    end
  end

  local space = string.rep(" ", n_space)
  local str_added = ("%s%s"):format(space, str)

  vim.api.nvim_buf_set_lines(0, n_insert_line - 1, n_insert_line - 1, false, { str_added })

  -- Waiting for https://github.com/neovim/neovim/issues/19832
  -- to avoid putting this jump in the jumplist
  vim.api.nvim_win_set_cursor(0, { n_insert_line, pos[2] })
end

return M
