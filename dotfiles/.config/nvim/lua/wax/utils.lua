-------- Debug utils --------

local function open_scratch_win(content, opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("keep", opts or {}, { width = 0.6, height = 0.6 })

  local bufnr = vim.api.nvim_create_buf(false, true)
  local ui = vim.api.nvim_list_uis()[1]

  local win_opts = {
    relative = "editor",
    anchor = "NW",
    style = "minimal",
    width = math.floor(opts.width * ui.width),
    height = math.floor(opts.height * ui.height),
    col = math.floor((0.5 - opts.width / 2) * ui.width),
    row = math.floor((0.4 - opts.height / 2) * ui.height),
    border = "rounded",
    noautocmd = true,
  }

  local win = vim.api.nvim_open_win(bufnr, true, win_opts)

  local close = function()
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  local mappings = {
    q = close,
  }
  vim.api.nvim_create_autocmd("WinLeave", { callback = close, buffer = bufnr })

  for k, v in pairs(mappings) do
    if type(v) == "string" then
      vim.api.nvim_buf_set_keymap(bufnr, "n", k, v, { nowait = true })
    else
      vim.api.nvim_buf_set_keymap(bufnr, "n", k, "", { callback = v, nowait = true })
    end
  end

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

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, content)
end

---Dump the args in vim messages
---@param ... unknown
function _G.dump(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
  print(unpack(objects))
end

---Dump the args inside a floating window scratch buffer
---@param ... unknown
function _G.dumpf(...)
  local content = vim.tbl_map(vim.inspect, { ... })
  open_scratch_win(content)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.keymap.set("v", "<c-a>", function()
      -- waiting for lua "get_visual_selection"
      -- https://github.com/neovim/neovim/pull/13896
      vim.cmd([[normal! "y]])
      local selection = vim.fn.getreg('"')

      -- Pulled from luaeval function
      local chunkheader = "local _A = select(1, ...) return "
      local result = loadstring(chunkheader .. selection, "debug")()

      local content = { selection, "", vim.inspect(result) }
      open_scratch_win(content)
    end)
  end,
})

-------- Mocks --------

function _G.mock(opts)
  local Mock = opts or {}
  setmetatable(Mock, {
    __call = function(...)
      -- log.warn(("called __call with args=%s"):format(...))
      return Mock
    end,
    __index = function(...)
      -- log.warn(("called __index with args=%s"):format(...))
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

---Try to require. If module is not available, returns a mock.
---@param name string
---@return unknown
function _G.safe_require(name)
  local res, mod = pcall(require, name)
  if not res then
    log.error(mod)
    return mock()
  else
    return mod
  end
end

-------- Logs --------

_G.log = safe_require("plenary.log").new({
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
  local stdout, ret = Job
      :new({
        command = command,
        args = cmd,
        cwd = cwd,
        on_stderr = function(_, data)
          table.insert(stderr, data)
        end,
      })
      :sync()
  return stdout, ret, stderr
end

function _G.is_git(cwd)
  cwd = cwd or vim.fn.getcwd()
  local cmd = { "git", "rev-parse", "--show-toplevel" }
  local git_root, ret = _G.get_os_command_output(cmd, cwd)
  return not (ret ~= 0 or #git_root <= 0)
end

function _G.find_root_dir_fn(patterns)
  local default_patterns = {
    ".git",
    "Dockerfile",
    "pyproject.toml",
    "setup.cfg",
    "package.json",
    "tsconfig.json",
  }
  patterns = patterns or default_patterns
  return require("lspconfig").util.root_pattern(patterns)
end

function _G.find_root_dir(path)
  return find_root_dir_fn()(path)
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

-- vim.keymap.set("t", "<c-g>", "<cmd>stopinsert<cr>")

local M = {}

function M.insert_new_line_in_current_buffer(str, opts)
  local default_opts = { delta = 1 }
  opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

  local pos = vim.api.nvim_win_get_cursor(0)
  local n_line = pos[1]

  local n_insert_line = n_line + opts.delta

  -- deduce indent for line:
  local n_space = vim.fn.indent(n_line)

  -- if treesitter available, might use it to correct corner cases:
  local has_treesitter = is_module_available("nvim-treesitter.indent")
  if has_treesitter and n_space == 0 then
    local ts_indent = require("nvim-treesitter.indent")
    n_space = ts_indent.get_indent(n_insert_line)
  end

  local space = string.rep(" ", n_space)
  local str_added = ("%s%s"):format(space, str)

  vim.api.nvim_buf_set_lines(0, n_insert_line - 1, n_insert_line - 1, false, { str_added })
  vim.api.nvim_win_set_cursor(0, { n_insert_line, pos[2] })
end

return M
