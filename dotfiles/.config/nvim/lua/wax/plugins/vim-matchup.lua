vim.cmd([[
  hi MatchBackground cterm=none ctermbg=none

  hi MatchParenCur cterm=none ctermbg=none
  hi MatchParen cterm=none ctermbg=none

  hi MatchWord cterm=none ctermbg=none
  hi MatchWordCur cterm=none ctermbg=none
]])

vim.g.matchup_enabled = 1
vim.g.matchup_mouse_enabled = 0
vim.g.matchup_text_obj_enabled = 0
vim.g.matchup_transmute_enabled = 0
vim.g.matchup_matchparen_offscreen = {}

-- Wrong matching (HTML)
-- https://github.com/andymass/vim-matchup/issues/19
vim.g.matchup_matchpref = { html = { nolists = 1 } }
