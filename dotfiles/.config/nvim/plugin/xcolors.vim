let g:gruvbox_invert_selection=0
"let g:gruvbox_improved_strings=1
let g:gruvbox_improved_warnings=1
silent! colorscheme gruvbox " use of silence in case plugin are not yet installed

" limelight
let g:limelight_conceal_ctermfg=244

highlight Normal ctermbg=none
highlight VertSplit ctermbg=none
highlight CursorLineNr ctermbg=none
highlight ColorColumn ctermbg=236

" Better Fold
" highlight Folded ctermbg=236
highlight Folded cterm=bold ctermbg=none
hi! link Folded GruvboxFg3

" Better Sign Column
highlight SignColumn ctermbg=none

highlight CocHintHighlight cterm=none

highlight CocHintSign ctermbg=none ctermfg=Blue
highlight CocInfoSign ctermbg=none ctermfg=White
highlight CocWarningSign ctermbg=none ctermfg=Yellow
highlight CocErrorSign ctermbg=none ctermfg=Red cterm=none
hi! link CocErrorSign GruvboxRed

highlight AleHintSign ctermbg=none ctermfg=Blue
highlight AleInfoSign ctermbg=none ctermfg=White
highlight AleWarningSign ctermbg=none ctermfg=Yellow
highlight AleErrorSign ctermbg=none ctermfg=Red cterm=none
hi! link AleErrorSign GruvboxRed

highlight GitGutterAdd ctermbg=none ctermfg=Green
highlight GitGutterChange ctermbg=none ctermfg=Yellow
highlight GitGutterDelete ctermbg=none ctermfg=Red

" Better diff views
highlight DiffAdd cterm=none ctermfg=Green ctermbg=none
highlight DiffChange cterm=none ctermfg=Yellow ctermbg=none
highlight DiffDelete cterm=bold ctermfg=Red ctermbg=none
highlight DiffText cterm=none ctermfg=Blue ctermbg=none

" Better Coc Virtual Text
highlight CocErrorVirtualText ctermfg=Red ctermbg=none
highlight CocWarningVirtualText ctermfg=Yellow ctermbg=none
highlight CocInfoVirtualText ctermfg=Blue ctermbg=none

" LSP colors
highlight LspReferenceRead cterm=bold ctermbg=red guibg=#464646
highlight LspReferenceText cterm=bold ctermbg=red guibg=#464646
highlight LspReferenceWrite cterm=bold ctermbg=red guibg=#464646


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
