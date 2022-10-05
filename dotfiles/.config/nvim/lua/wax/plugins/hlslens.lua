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
})

vim.api.nvim_set_hl(0, "HlSearchLensNear", { link = "Comment" })

-- hi default link HlSearchNear IncSearch
-- hi default link HlSearchLens WildMenu
-- hi default link HlSearchLensNear IncSearch
-- hi default link HlSearchFloat IncSearch
