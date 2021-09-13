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