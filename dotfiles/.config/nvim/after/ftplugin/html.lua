vim.opt_local.foldmethod = "indent"
vim.opt_local.wrap = false

vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2

-- Solve issue on mini ai with nested html tags
-- https://github.com/echasnovski/mini.nvim/issues/110
vim.b.miniai_disable = true
