local opts = { silent = true }

nmap("<leader>1", ":Tmux <CR>:TestNearest<CR>", opts)
nmap("<leader>2", ":Tmux <CR>:TestLast<CR>", opts)
nmap("<leader>3", ":Tmux <CR>:TestFile<CR>", opts)

nmap("<leader>v", "<Plug>SetTmuxVars")

vim.g.tslime_always_current_session = 1
vim.g.tslime_always_current_window = 1

vim.api.nvim_set_var("test#strategy", "tslime")
vim.api.nvim_set_var("test#preserve_screen", 1)
vim.api.nvim_set_var("test#filename_modifier", ":~")

-- python
vim.api.nvim_set_var("test#python#runner", "pytest")
vim.api.nvim_set_var("test#python#pytest#options", "--log-level=WARNING -x -s")
