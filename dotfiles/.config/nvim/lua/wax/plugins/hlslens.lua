local kmap = vim.keymap.set
local kopts = { silent = true }

kmap(
  "n",
  "n",
  [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
  kopts
)
kmap(
  "n",
  "N",
  [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
  kopts
)

kmap("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
kmap("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
kmap("n", "g*", [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
kmap("n", "g#", [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)

kmap("n", "<leader>;", ":noh<CR>", kopts)

require("hlslens").setup({
  nearest_only = true,
  nearest_float_when = "never",
  -- calm_down = true,
  override_lens = function(...) end, -- disable virtual text
})
