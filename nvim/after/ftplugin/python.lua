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
