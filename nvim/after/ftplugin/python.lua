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

local function _get_python_parts()
  vim.cmd([[normal! "wyiw]])
  local word_under_cursor = vim.fn.getreg('"')

  local abspath = vim.api.nvim_buf_get_name(0)
  local workspace = find_root_dir(abspath, { "pyproject.toml" })
  if not workspace then
    return
  end

  local Path = require("wax.path")
  local relpath = Path:new(abspath):make_relative(workspace).path
  if not string.match(relpath, ".py$") then
    return
  end

  local module = string.gsub(relpath, "/", "."):gsub("%.py$", "")

  return module, word_under_cursor
end

vim.keymap.set("n", "<leader>yP", function()
  local module, word_under_cursor = _get_python_parts()

  vim.fn.setreg("+", ("from %s import %s"):format(module, word_under_cursor))
end, { desc = "Yank current file python word as import" })

vim.keymap.set("n", "<leader>yp", function()
  local module, word_under_cursor = _get_python_parts()
  vim.fn.setreg("+", ("%s.%s"):format(module, word_under_cursor))
end, { desc = "Yank current file python word as module" })
