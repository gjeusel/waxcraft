vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4

vim.g.python3_host_prog = require("wax.lsp.python-utils").get_python_path()

local utils = require("wax.utils")

vim.keymap.set("n", "<leader>o", function()
  utils.insert_new_line_in_current_buffer('__import__("pdb").set_trace()  # BREAKPOINT')
end, {
  buffer = 0,
  desc = "Insert pdb breakpoint below.",
})
vim.keymap.set("n", "<leader>O", function()
  utils.insert_new_line_in_current_buffer(
    '__import__("pdb").set_trace()  # BREAKPOINT',
    { delta = 0 }
  )
end, {
  buffer = 0,
  desc = "Insert pdb breakpoint above.",
})


local Path = require("wax.path")

local python_root_markers = { "pyproject.toml", "setup.py", "setup.cfg", ".git" }

--- Find importable symbol (class/def/async def/module-level var) from a line of code.
---@return string|nil symbol, string|nil indent
local function find_importable_symbol(code)
  local var = code:match("^([a-zA-Z_][a-zA-Z0-9_]*)%s*=")
  if var then
    return var, ""
  end
  for _, pattern in ipairs({
    "^(%s*)class%s+([a-zA-Z_][a-zA-Z0-9_]*)",
    "^(%s*)def%s+([a-zA-Z_][a-zA-Z0-9_]*)",
    "^(%s*)async%s+def%s+([a-zA-Z_][a-zA-Z0-9_]*)",
  }) do
    local indent, symbol = code:match(pattern)
    if indent and symbol then
      return symbol, indent
    end
  end
  return nil, nil
end

--- Walk up from cursor line to build a chain of nested symbols (e.g. {"MyClass", "my_method"}).
---@param lines string[]
---@return string[]
local function get_symbol_chain(lines)
  if #lines == 0 then
    return {}
  end
  local symbol, indent = find_importable_symbol(lines[#lines])
  if not symbol or not indent then
    return {}
  end
  local symbols = { symbol }
  local current_indent = #indent
  for i = #lines - 1, 1, -1 do
    symbol, indent = find_importable_symbol(lines[i])
    if symbol and indent and #indent < current_indent then
      table.insert(symbols, 1, symbol)
      current_indent = #indent
      if #indent == 0 then
        break
      end
    end
  end
  return symbols
end

--- Resolve the dotted module path and symbol chain for the current cursor position.
---@return string dotted_path, string[] symbol_chain
local function get_python_path_parts()
  local filepath = vim.fs.normalize(vim.fn.expand("%:p"))
  local root = Path:new(filepath):find_root_dir(python_root_markers)
  local root_path = root and root.path or vim.fs.dirname(filepath)
  if not root_path:match("/$") then
    root_path = root_path .. "/"
  end

  local relative = filepath:sub(#root_path + 1)
  local module_dotted = relative:gsub("/", "."):gsub("%.py$", "")

  -- Handle __init__.py: strip trailing .__init__
  module_dotted = module_dotted:gsub("%.__init__$", "")

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor_line, false)
  local symbol_chain = get_symbol_chain(lines)

  return module_dotted, symbol_chain
end

vim.keymap.set("n", "<leader>yp", function()
  local module, symbols = get_python_path_parts()
  local dotted = module
  if #symbols > 0 then
    dotted = dotted .. "." .. table.concat(symbols, ".")
  end
  vim.fn.setreg("+", dotted)
  vim.notify(dotted, vim.log.levels.INFO)
end, { buffer = 0, desc = "Yank python dotted path" })

vim.keymap.set("n", "<leader>yP", function()
  local module, symbols = get_python_path_parts()
  local result
  if #symbols > 0 then
    result = ("from %s import %s"):format(module, symbols[1])
  else
    result = "import " .. module
  end
  vim.fn.setreg("+", result)
  vim.notify(result, vim.log.levels.INFO)
end, { buffer = 0, desc = "Yank python import statement" })
