vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4

vim.o.autoindent = true -- use previous line indent

vim.g.python_indent = {
  open_paren = "&sw",
  nested_paren = "&sw",
  continue = "&sw",
  closed_paren_align_last_line = false,
  searchpair_timeout = 150,
  disable_parentheses_indenting = true,
}

vim.g.pyindent_open_paren = "&sw"
vim.g.pyindent_nested_paren = "&sw"
vim.g.pyindent_continue = "&sw"
vim.g.pyindent_searchpair_timeout = 150
vim.g.pyindent_disable_parentheses_indenting = true

-- vim.g.python_indent.open_paren = "&sw"
-- vim.g.python_indent.nested_paren = "&sw"
-- vim.g.python_indent.continue = "&sw"
-- vim.g.python_indent.closed_paren_align_last_line = false
