local npairs = require("nvim-autopairs")

npairs.setup({
  disable_filetype = { "TelescopePrompt", "vim" },
  close_triple_quotes = true,
  enable_check_bracket_line = true, --- check bracket in same line
  check_ts = true,
  -- ts_config = {
  --     lua = {'string'},-- it will not add pair on that treesitter node
  --     javascript = {'template_string'},
  --     java = false,-- don't check treesitter on java
  -- },
})

require("nvim-autopairs.completion.compe").setup({
  map_cr = true, --  map <CR> on insert mode
  map_complete = true, -- it will auto insert `(` after select function or method item
})

local parenthesis_rule = npairs.get_rule("(")
parenthesis_rule:with_pair(function()
  if vim.fn.pumvisible() then
    vim.cmd([[ call timer_start(0, { -> luaeval('require"compe"._close()') }) ]])
  end
  return true
end)
