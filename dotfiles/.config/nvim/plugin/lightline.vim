" https://github.com/itchyny/lightline.vim/issues/87

let g:lightline = {
  \ 'colorscheme': 'gruvbox',
  \ 'component_function': {
  \   'gitbranch': 'FugitiveHead'
  \ },
\ }

" Register the components:
let g:lightline.component_expand = {
  \   'coc_warnings': 'lightline#coc#warnings',
  \   'coc_errors': 'lightline#coc#errors',
  \   'coc_ok': 'lightline#coc#ok',
  \   'status': 'lightline#coc#status',
  \   'ale_checking': 'lightline#ale#checking',
  \   'ale_infos': 'lightline#ale#infos',
  \   'ale_warnings': 'lightline#ale#warnings',
  \   'ale_errors': 'lightline#ale#errors',
  \   'ale_ok': 'lightline#ale#ok',
  \ }

" Set color to the components:
let g:lightline.component_type = {
  \   'linter_warnings': 'warning',
  \   'linter_errors': 'error',
  \   'linter_ok': 'left',
  \ }

let g:lightline_custom_layout = {
    \ 'left': [ [ 'mode', 'paste' ],
    \           [ 'coc_errors', 'coc_warnings', 'coc_ok',
    \             'ale_errors', 'ale_warnings', 'ale_ok',
    \             'readonly', 'modified' ]
    \ ],
    \ 'right': [ [  ],
    \            [  ],
    \            [ 'gitbranch', 'absolutepath', 'filetype' ]
    \ ]}

let g:lightline.inactive = lightline_custom_layout
let g:lightline.active = lightline_custom_layout
