vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4

vim.o.autoindent = true -- use previous line indent

vim.g.python_indent = {
  open_paren = "&sw",
  nested_paren = "&sw",
  continue = "&sw",
  closed_paren_align_last_line = false,
}
