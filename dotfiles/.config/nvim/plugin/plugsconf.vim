" Easy Align, used to tabularize map:
vmap <leader>t <Plug>(EasyAlign)

" Goyo
let g:goyo_width = 120
nmap <leader>go :Goyo <cr>

" indentLine
let g:indentLine_char = '│'
let g:indentLine_color_gui = '#343d46'  " indent line color got indentLine plugin
let g:indentLine_fileTypeExclude = ['startify', 'markdown', 'vim', 'tex', 'help']

" rainbow
let g:rainbow_active = 1 "0 if you want to enable it later via :RainbowToggle
let g:rainbow_conf = {
  \  'separately': {
  \    'vue': {
  \      'parentheses': [
  \        'start=/\v\<((script|style|area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr)[ >])@!\z([-_:a-zA-Z0-9]+)(\s+[-_:a-zA-Z0-9]+(\=("[^"]*"|'."'".'[^'."'".']*'."'".'|[^ '."'".'"><=`]*))?)*\>/ end=#</\z1># fold'
  \      ],
  \    },
  \ }
  \}
  " https://github.com/luochen1990/rainbow/issues/107
  " \       'start=/{/ end=/}/ fold containedin=vue_typescript',
  " \       'start=/(/ end=/)/ fold containedin=vue_typescript',


" SuperTab
let g:SuperTabMappingForward = '<S-Tab>'
let g:SuperTabMappingBackward = '<Tab>'

" tcomment
let g:tcomment_opleader1 = "<leader>c"
let g:tcomment#filetype#guess_vue = 0  " https://github.com/tomtom/tcomment_vim/issues/284#issuecomment-809956888

" Python - Pymode {{{
" syntax (colors for self keyword for example)
let g:pymode_syntax = 1
let g:pymode_syntax_all = 1

" Disable all the rest, we only want syntax coloring
let g:pymode_indent = 1 " pep8 indent
let g:pymode_folding = 0 " disable folding to use SimpyFold
let g:pymode_motion = 1  " give jumps to functions / methods / classes
let g:pymode_doc = 0
let g:pymode_trim_whitespaces = 0 " do not trim unused white spaces on save
let g:pymode_rope = 0 " disable rope
let g:pymode_lint = 0  " disable lint
let g:pymode_breakpoint = 0  " disable it for custom
let g:pymode_run_bind = ''  " don't bind <leader>r used for references

function! s:setPyModeMappings()
  map <buffer> <Leader>o o__import__("pdb").set_trace()  # BREAKPOINT<C-c>
  map <buffer> <Leader>O O__import__("pdb").set_trace()  # BREAKPOINT<C-c>
  "import pdb; pdb.break_on_setattr('session_id')(container._sa_instance_state.__class__)
  "map <Leader>i ofrom ptpython.repl import embed; embed()  # Enter ptpython<C-c>
  map <buffer> <Leader>i o__import__("IPython").embed()  # ipython embed<C-c>
endfunction

augroup python_pymode_mappings
  au Filetype python call s:setPyModeMappings()
augroup end
" }}}

" Frontend {{{
" Vue
let g:vim_vue_plugin_load_full_syntax = 1
let g:vim_vue_plugin_highlight_vue_attr = 1
let g:vim_vue_plugin_highlight_vue_keyword = 1
let g:vim_vue_plugin_use_foldexpr = 0
let g:vue_pre_processors = ['typescript']
let g:vue_pre_processors = []

" Emmet:
imap <expr> <C-d> emmet#expandAbbrIntelligent("\<tab>")

function! s:setFrontendMappings()
  map <buffer> <Leader>o odebugger  // BREAKPOINT<C-c>
  map <buffer> <Leader>O Odebugger  // BREAKPOINT<C-c>
endfunction
augroup frontend_mappings
  au Filetype vue,typescript,javascript call s:setFrontendMappings()
augroup end
" }}}

" Lint ALE {{{
let g:ale_sign_error = '✖'   " Lint error sign
let g:ale_sign_warning = '⚠' " Lint warning sign

" - alex: helps you find gender favouring, polarising, race related, religion inconsiderate, or other unequal phrasing

" Only run linters named in ale_linters settings.
let g:ale_linters_explicit = 1

let g:ale_linters = {
            \ '*': ['writegood', 'remove_trailing_lines', 'trim_whitespace'],
            \ 'python': ['flake8'],
            \ 'json': ['jsonlint'],
            \}

"\ 'python': ['autopep8', 'isort', 'black'],
let g:ale_fixers = {
            \ 'python': ['isort', 'black'],
            \ 'json': ['jq'],
            \}

let g:ale_javascript_prettier_options = '--single-quote --trailing-comma none --no-semi'

" choice of ignored errors in ~/.config/flake8

"let g:ale_fix_on_save = 0  " always fix at save time

function! s:setPythonAleMapping()
  " go to previous error in current windows
  map <buffer> <nowait><silent> <leader>[ <Plug>(ale_previous_wrap)
  map <buffer> <nowait><silent> å <Plug>(ale_previous_wrap)

  " go to next error in current windows
  map <buffer> <nowait><silent> <leader>] <Plug>(ale_next_wrap)
  map <buffer> <nowait><silent> ß <Plug>(ale_next_wrap)

  nmap <buffer> <leader>m :ALEFix <cr>
endfunction

augroup python_ale_mapping
  au FileType python call s:setPythonAleMapping()
augroup end

"}}}

" Table Mode, Restructured text compatible {{{
au BufNewFile,BufRead *.rst let g:table_mode_header_fillchar='='
au BufNewFile,BufRead *.rst let g:table_mode_corner_corner='+'

au BufNewFile,BufRead *.py let g:table_mode_header_fillchar='='
au BufNewFile,BufRead *.py let g:table_mode_corner_corner='+'

au BufNewFile,BufRead *.md let g:table_mode_header_fillchar='-'
au BufNewFile,BufRead *.md let g:table_mode_corner_corner='|'
"}}}

" Terraform {{{
let g:terraform_fmt_on_save=1
let g:terraform_fold_sections=1
let g:terraform_align=1
" }}}

" Test and tmux {{{
nmap <silent> <leader>1 :Tmux <CR>:TestNearest<CR>
nmap <silent> <leader>2 :Tmux <CR>:TestLast<CR>
nmap <silent> <leader>3 :Tmux <CR>:TestFile<CR>
nmap <leader>v <Plug>SetTmuxVars
let test#strategy = 'tslime'
let g:test#preserve_screen = 1
let test#filename_modifier = ':~' " ~/Code/my_project/test/models/user_test.rb
"let test#python#pytest#options = '--log-level=DEBUG -x -s --pdb'
let test#python#pytest#options = '--log-level=WARNING -x -s'
let g:tslime_always_current_session = 1
let g:tslime_always_current_window = 1
"}}}

" TagBar & UndoTree & NERDTree
nnoremap <silent> <F7> :NERDTreeToggle<CR>
nnoremap <silent> <F8> :UndotreeToggle<CR>
nnoremap <silent> <F9> :TagbarToggle<CR>

" Loupe
let g:LoupeClearHighlightMap = 0
let g:LoupeVeryMagic = 0

" tmux, disable tmux navigator when zooming the Vim pane
let g:tmux_navigator_disable_when_zoomed = 1
