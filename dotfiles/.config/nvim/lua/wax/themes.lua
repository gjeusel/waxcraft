-- vim.cmd("syntax on")

-- vim.o.termguicolors = true
vim.o.colorcolumn = "100" -- Show vertical bar at column 100
vim.o.signcolumn = "yes"

-- vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.gruvbox_invert_selection = 0
vim.g.gruvbox_improved_warnings = 1

vim.g.nord_disable_background = true

-- Highlight API is still a wip in nvim: https://github.com/nanotee/nvim-lua-guide#defining-syntaxhighlights

-- TreeSitter list of highlights:
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/8adb2e0352858d1b12c0b4ee3617c9f38ed8c53b/lua/nvim-treesitter/highlight.lua

-- Gruvbox Specific
local apply_gruvbox_theme = function()
  vim.api.nvim_exec(
    [[
" Statusline
hi! link Statusline GruvboxFg3

" barbar
hi! link BufferCurrent GruvboxFg1
hi! link BufferCurrentSign GruvboxAqua
hi! link BufferVisible GruvboxFg2
hi! link BufferVisibleSign GruvboxBlue
hi! link BufferInactive GruvboxFg4
hi! link BufferInactiveSign GruvboxFg4

hi! link BufferTabpages GruvboxBg0
hi! link BufferTabpageFill GruvboxBg0

" Better Fold
highlight Folded cterm=bold ctermbg=none
hi! link Folded GruvboxFg3

" Lsp
hi! link DiagnosticError GruvboxRed
hi! link DiagnosticWarn GruvboxYellow
hi! link DiagnosticInfo GruvboxFg3
hi! link DiagnosticHint GruvboxBlue

" nvim-cmp
hi! link CmpItemAbbrMatch GruvboxFg3
hi! link CmpItemAbbrMatchFuzzy GruvboxFg3
hi! link CmpItemKind GruvboxFg4
hi! link CmpItemMenu GruvboxBg4
hi! CmpItemAbbrDeprecated cterm=strikethrough

" LightSpeed
hi! link LightspeedShortcut GruvboxRedSign
hi! link LightspeedShortcutOverlapped GruvboxRedSign
hi! link LightspeedOneCharMatch GruvboxRedSign
hi! link LightspeedPendingOpArea GruvboxRedSign
hi! link LightspeedLabel GruvboxRedSign

"" LSP colors
"highlight LspReferenceRead cterm=bold ctermbg=red guibg=#464646
"highlight LspReferenceText cterm=bold ctermbg=red guibg=#464646
"highlight LspReferenceWrite cterm=bold ctermbg=red guibg=#464646

" gitsigns
hi! link GitSignsDelete GruvboxRed
hi! link GitSignsChange GruvboxYellow
hi! link GitSignsAdd GruvboxAqua

]],
    false
  )
end

-- TreeSitter + Gruvbox
local apply_treesitter_frontend_theme = function()
  vim.api.nvim_exec(
    [[
" TreeSitter for TypeScript and Vue
hi! link TSProperty white
hi! link TSParameter white
hi! link TSConstant white
hi! link TSVariable white
hi! link TSField white
hi! link TSConstructor white

hi! link TSVariableBuiltin GruvboxOrange

hi! link TSFunction GruvboxBlue
hi! link TSMethod GruvboxBlue

hi! link TSType GruvboxYellow
hi! link TSTypeBuiltin GruvboxYellow

hi! link TSPunctSpecial GruvboxFg3
hi! link TSPunctBracket GruvboxFg3
hi! link TSPunctDelimiter white
]],
    false
  )
end

local apply_treesitter_python_theme = function()
  vim.api.nvim_exec(
    [[
  hi! link pythonTSInclude GruvboxBlue

  hi! link pythonTSKeywordOperator GruvboxRed
  hi! link pythonTSBoolean GruvboxOrange

  hi! link pythonTSNone GruvboxFg1  " fstring interpolation

  hi! link pythonTSPunctDelimiter white
  hi! link pythonTSPunctBracket white
  hi! link pythonTSPunctSpecial GruvboxOrange  " { } of f-string

  hi! link pythonTSOperator GruvboxFg1

  hi! link pythonTSConstant white
  hi! link pythonTSConstructor white
  hi! link pythonTSField white

  hi! link pythonTSConstant white
  hi! link pythonTSVariable white
  hi! link pythonTSParameter white

  hi! link pythonTSType GruvboxYellow
  hi! link pythonTSMethod GruvboxAqua
  hi! link pythonTSFunction GruvboxAqua
  hi! link pythonTSConstructor GruvboxGreen  " used for decorators

  hi! link pythonTSVariableBuiltin GruvboxBlue
  hi! link pythonTSFuncBuiltin GruvboxYellow
  hi! link pythonTSConstBuiltin GruvboxOrange
]],
    false
  )
end

if iterm_colorscheme == "gruvbox" then
  vim.cmd("silent! colorscheme gruvbox")
  apply_gruvbox_theme()
  apply_treesitter_frontend_theme()
  apply_treesitter_python_theme()
elseif iterm_colorscheme == "nord" then
  require("wax.themes.nord")
end

vim.api.nvim_exec(
  [[
" Base interface
highlight Normal ctermbg=none
highlight SignColumn ctermbg=none
highlight VertSplit ctermbg=none
highlight CursorLineNr ctermbg=none
highlight EndOfBuffer ctermbg=none
highlight ColorColumn ctermbg=236

" Better diff views
highlight DiffAdd cterm=none ctermfg=Green ctermbg=none
highlight DiffChange cterm=none ctermfg=Yellow ctermbg=none
highlight DiffDelete cterm=bold ctermfg=Red ctermbg=none
highlight DiffText cterm=none ctermfg=Blue ctermbg=none

" Better floating windows
highlight NormalFloat ctermbg=none
  ]],
  false
)

M = {}

M.apply_treesitter_gruvbox_theme = function()
  apply_treesitter_frontend_theme()
  apply_treesitter_python_theme()
end

nnoremap("<leader>xc", "<cmd>TSHighlightCapturesUnderCursor<cr>")
nnoremap(
  "<leader>xz",
  "<cmd>lua require('plenary.reload').reload_module('wax.themes'); require('wax.themes').apply_treesitter_gruvbox_theme()<cr>"
)

return M
