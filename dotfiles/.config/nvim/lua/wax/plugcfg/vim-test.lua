local tmux = require("wax.tmux")

local kmap = vim.keymap.set

local kopts = { silent = true }

kmap("n", "<leader>1", ":Tmux <CR>:TestNearest<CR>", kopts)
kmap("n", "<leader>2", ":Tmux <CR>:TestLast<CR>", kopts)
kmap("n", "<leader>3", ":Tmux <CR>:TestFile<CR>", kopts)
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

-- vue
-- vim.api.nvim_set_var("test#javascript#runner", "npm run test")

-- python
vim.api.nvim_set_var("test#python#runner", "pytest")
vim.api.nvim_set_var("test#python#pytest#options", "--log-cli-level=INFO")

kmap("n", "<leader>5", function()
  local items = {
    { name = "pdb-info", options = { "--pdb", "--exitfirst", "--log-cli-level=INFO", "-vv" } },
    { name = "pdb-debug", options = { "--pdb", "--exitfirst", "--log-cli-level=DEBUG", "-vv" } },
    { name = "verbose-info", options = { "--log-cli-level=INFO" } },
    { name = "pdb-snapshot", options = { "--pdb", "--snapshot-update" } },
    { name = "none", options = {} },
  }

  local opts = {
    prompt = "Toogle pytest opts> ",
    format_item = function(item)
      return ("%-18s │ '%s'"):format(item["name"], table.concat(item["options"], " ") or "")
    end,
  }

  vim.ui.select(items, opts, function(choice)
    local varname = "test#python#pytest#options"
    vim.api.nvim_set_var(varname, table.concat(choice["options"], " "))
  end)
end)
