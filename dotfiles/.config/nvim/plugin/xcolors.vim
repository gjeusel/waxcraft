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

" Better Sign Column
highlight SignColumn ctermbg=none
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
