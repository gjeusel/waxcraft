local tmux = require("wax.tmux")

local kmap = vim.keymap.set

local opts = { silent = true }

kmap("n", "<leader>1", ":Tmux <CR>:TestNearest<CR>", opts)
kmap("n", "<leader>2", ":Tmux <CR>:TestLast<CR>", opts)
kmap("n", "<leader>3", ":Tmux <CR>:TestFile<CR>", opts)
kmap("n", "<leader>4", tmux.tslime_select_target_pane)

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = tmux.tslime_auto_select_bottom_pane,
})

vim.g.tslime_always_current_session = 1
vim.g.tslime_always_current_window = 1

vim.api.nvim_set_var("test#strategy", "tslime")
vim.api.nvim_set_var("test#preserve_screen", 1)
vim.api.nvim_set_var("test#filename_modifier", ":~")
vim.api.nvim_set_var("test#echo_command", 0)

-- python
vim.api.nvim_set_var("test#python#runner", "pytest")
vim.api.nvim_set_var("test#python#pytest#options", "--log-cli-level=INFO --log-level=INFO -x -s")

-- vue
-- vim.api.nvim_set_var("test#javascript#runner", "npm run test")
