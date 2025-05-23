local tmux = require("wax.tmux")

local kmap = vim.keymap.set

local kopts = { silent = true }

vim.api.nvim_set_var("test#custom_strategies", {
  wax_tmux = function(cmd)
    tmux.run_in_pane(cmd, { interrupt_before = true, clear_before = true })
  end,
})
vim.api.nvim_set_var("test#strategy", "wax_tmux")
vim.api.nvim_set_var("test#preserve_screen", 1)
vim.api.nvim_set_var("test#filename_modifier", ":~")
vim.api.nvim_set_var("test#echo_command", 0)

-- python
vim.api.nvim_set_var("test#python#runner", "pytest")
vim.api.nvim_set_var("test#python#pytest#options", "-s")

-- -- vue
-- vim.api.nvim_set_var("test#javascript#runner", "npm run test")

kmap("n", "<leader>1", ":TestNearest<CR>", kopts)
kmap("n", "<leader>2", ":TestLast<CR>", kopts)
kmap("n", "<leader>3", ":TestFile<CR>", kopts)
kmap("n", "<leader>4", tmux.select_target_pane)

kmap("n", "<leader>5", function()
  local items = {
    { name = "pdb-snapshot-json", options = "--snapshot='json' -vv" },
    { name = "pdb-snapshot", options = "--snapshot='all' -vv" },
    --
    { name = "pdb-last-fail", options = "--pdb -xs --log-cli-level=DEBUG -vv --lf" },
    { name = "pdb-debug", options = "--pdb -xs --log-cli-level=DEBUG -vv" },
    { name = "pdb-fast", options = "-n 4" },
    { name = "pdb-module", options = "" },
  }

  local opts = {
    prompt = "Toogle pytest opts> ",
    format_item = function(item)
      return item.name .. " | " .. item.options
    end,
  }

  vim.ui.select(items, opts, function(choice)
    if choice == nil then
      return
    end

    local varname = "test#python#pytest#options"
    local before = vim.api.nvim_get_var(varname)
    vim.api.nvim_set_var(varname, choice.options)
    vim.defer_fn(function()
      vim.api.nvim_set_var(varname, before)
    end, 3000)

    vim.cmd("stopinsert")

    if vim.list_contains({ "pdb-fast", "pdb-module" }, choice.name) then
      vim.cmd(":TestFile")
    else
      vim.cmd(":TestNearest")
    end
  end)
end)
