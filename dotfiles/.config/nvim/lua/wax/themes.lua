vim.cmd("syntax on")

-- vim.o.termguicolors = true
vim.o.colorcolumn = "100" -- Show vertical bar at column 100
vim.o.signcolumn = "yes"

-- vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.gruvbox_invert_selection = 0
vim.g.gruvbox_improved_warnings = 1

vim.g.nord_disable_background = true

-- Highlight API is still a wip in nvim: https://github.com/nanotee/nvim-lua-guide#defining-syntaxhighlights

vim.api.nvim_exec(
  [[
" Base interface
highlight Normal ctermbg=none
highlight SignColumn ctermbg=none
highlight VertSplit ctermbg=none
highlight CursorLineNr ctermbg=none
highlight ColorColumn ctermbg=236
highlight SignColumn ctermbg=none

" Better diff views
highlight DiffAdd cterm=none ctermfg=Green ctermbg=none
highlight DiffChange cterm=none ctermfg=Yellow ctermbg=none
highlight DiffDelete cterm=bold ctermfg=Red ctermbg=none
highlight DiffText cterm=none ctermfg=Blue ctermbg=none
  ]],
  false
)

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
hi! link LspDiagnosticsDefaultError GruvboxRed
hi! link LspDiagnosticsDefaultWarning GruvboxYellow
hi! link LspDiagnosticsDefaultInformation GruvboxFg3
hi! link LspDiagnosticsDefaultHint GruvboxBlue

"" LSP colors
"highlight LspReferenceRead cterm=bold ctermbg=red guibg=#464646
"highlight LspReferenceText cterm=bold ctermbg=red guibg=#464646
"highlight LspReferenceWrite cterm=bold ctermbg=red guibg=#464646

" gitsigns
hi! link GitSignsDelete GruvboxRed
hi! link GitSignsChange GruvboxYellow
hi! link GitSignsAdd GruvboxAqua


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

if iterm_colorscheme == "gruvbox" then
  vim.cmd("silent! colorscheme gruvbox")
  apply_gruvbox_theme()
end
