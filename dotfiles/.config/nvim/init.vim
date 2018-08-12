"/ vim: set sw=4 ts=4 sts=4 et tw=78 foldmarker={{{,}}} foldlevel=0 foldmethod=marker spell:
"  _   _   __  __   __  __  _  ___  __   _   _  _  __ __
" | | | | /  \ \ \_/ / |  \| || __|/__\ | \ / || ||  V  |
" | 'V' || /\ | > , <  | | ' || _|| \/ |`\ V /'| || \_/ |
" !_/ \_!|_||_|/_/ \_\ |_|\__||___|\__/   \_/  |_||_| |_|

set encoding=UTF-8
let mapleader=","

" Plugins {{{

" Setup dein
  if (!isdirectory(expand("$HOME/.config/nvim/repos/github.com/Shougo/dein.vim")))
    call system(expand("mkdir -p $HOME/.config/nvim/repos/github.com"))
    call system(expand("git clone https://github.com/Shougo/dein.vim $HOME/.config/nvim/repos/github.com/Shougo/dein.vim"))
  endif

  set runtimepath+=~/.config/nvim/repos/github.com/Shougo/dein.vim/
  call dein#begin(expand('~/.config/nvim'))

  call dein#add('Shougo/dein.vim')

" System {{{
  call dein#add('christoomey/vim-tmux-navigator') " tmux navigation in love with vim
  call dein#add('scrooloose/nerdcommenter')  " easy comments
  call dein#add('terryma/vim-smooth-scroll')  " smooth scroll

  call dein#add('tpope/vim-surround') " change surrounding easily
  call dein#add('tpope/vim-repeat') " better action repeat for vim-surround with .
  call dein#add('vim-scripts/loremipsum')  " dummy text generator (:Loremipsum [number of words])
  call dein#add('easymotion/vim-easymotion')  " easymotion when fedup to think
  call dein#add('skywind3000/asyncrun.vim')  " run async shell commands
  call dein#add('Konfekt/FastFold')  " update folds only when needed, otherwise folds slowdown vim
  call dein#add('junegunn/vim-easy-align')  " easy alignment, better than tabularize
  call dein#add('majutsushi/tagbar') " browsing the tags, require ctags
  call dein#add('mattn/gist-vim')  " easily upload gist on github
  call dein#add('mbbill/undotree')  " visualize undo tree
  call dein#add('jiangmiao/auto-pairs') " auto pair

  call dein#add('terryma/vim-multiple-cursors')  " nice plugin for multiple cursors
  call dein#add('junegunn/fzf.vim')  " asynchronous fuzzy finder, should replace ctrlp if ever to work with huuge projects
"}}}

" User Interface {{{
  call dein#add('scrooloose/nerdtree')  " file tree
  call dein#add('itchyny/lightline.vim')  " light status line
  call dein#add('ap/vim-buftabline')  " buffer line
  call dein#add('Shougo/defx.nvim')  " thin indent line
  call dein#add('rhysd/conflict-marker.vim') " conflict markers for vimdiff
  call dein#add('luochen1990/rainbow')  " embed parenthesis colors
  call dein#add('altercation/vim-colors-solarized')  " prefered colorscheme
  "call dein#add('morhetz/gruvbox') " other nice colorscheme
  call dein#add('ryanoasis/vim-devicons')  " nice icons added
  call dein#add('blueyed/vim-diminactive') " dim inactive windows
" }}}

" Other languages syntax highlight {{{
  call dein#add('LnL7/vim-nix')  " for .nix
  call dein#add('cespare/vim-toml')  " syntax for .toml
  call dein#add('tmux-plugins/vim-tmux')  " syntax highlight for .tmux.conf file

"}}}

" Git {{{
  call dein#add('airblade/vim-gitgutter') " column sign for git changes
  call dein#add('tpope/vim-fugitive') " Git wrapper for vim
  call dein#add('tpope/vim-rhubarb')  " GitHub extension for fugitive.vim
  "call dein#add('jreybert/vimagit', {'on_cmd': ['Magit', 'MagitOnly']}) " magit for vim
" }}}

" markdown & rst {{{
  call dein#add('dhruvasagar/vim-table-mode')  " to easily create tables.
  call dein#add('rhysd/vim-grammarous')  " grammar checker
  call dein#add('junegunn/goyo.vim')  "  Distraction-free writing in Vim

  " plugin that adds asynchronous Markdown preview to Neovim
  " > cargo build --release   # should be run in vim-markdown-composer after
  " installation
  call dein#add('euclio/vim-markdown-composer', {'build': 'cargo build --release'})
" }}}

" Completion {{{
  call dein#add('ervandew/supertab') " use <Tab> for all your insert completion
  call dein#add('Shougo/deoplete.nvim')  " async engine

  call dein#add('Shougo/neoinclude.vim')  " completion framework for neocomplete/deoplete
  call dein#add('Shougo/neco-vim') " for vim

  call dein#add('zchee/deoplete-jedi') " for python
  call dein#add('zchee/deoplete-go')  " for golang
  call dein#add('carlitux/deoplete-ternjs')  " for javascript

  call dein#add('Shougo/echodoc.vim') " displays function signatures from completions in the command line.
" }}}

" Code Style {{{
  call dein#add('w0rp/ale')  " general asynchronous syntax checker
  call dein#add('editorconfig/editorconfig-vim')  " EditorConfig plugin for Vim
"}}}

" Python {{{
  call dein#add('tmhedberg/SimpylFold', {'on_ft': 'python'})  " better folds
  call dein#add('davidhalter/jedi-vim', {'on_ft': ['python', 'markdown', 'rst']})
  call dein#add('tell-k/vim-autopep8', {'on_ft': 'python'})  " still kept for ranged syntax fix
  "call dein#add('python-mode/python-mode')
  "call dein#add('nvie/vim-flake8')
"}}}

" Javascript, Html & CSS {{{
  call dein#add('wooorm/alex', {'on_ft': ['html', 'js', 'css']})  " general syntax checker

  call dein#add('eslint/eslint', {'on_ft': ['html', 'js', 'css']})  " javascript

  "call dein#add('othree/html5.vim')  " HTML5 omnicomplete and syntax
  call dein#add('yaniswang/HTMLHint', {'on_ft': 'html'})  " html
  call dein#add('tmhedberg/matchit', {'on_ft': 'html'})  " % for matching tag
  call dein#add('rstacruz/sparkup')  " for html auto generation

  call dein#add('mattn/emmet-vim', {'on_ft': ['html', 'js', 'css']}) " for html - CSS - javascript

  call dein#add('ap/vim-css-color', {'on_ft': 'css'})  " change bg color in css for colors
"}}}

" Golang {{{
  call dein#add('fatih/vim-go', {'on_ft': 'go'})
" }}}

" Snippets {{{
  "call dein#add('Shougo/neosnippet.vim')  " shougo snippet engine
  "call dein#add('Shougo/neosnippet-snippets')
  call dein#add('SirVer/ultisnips') " snippet engine
  call dein#add('honza/vim-snippets') " those are the best snippets for python
"}}}

  if dein#check_install()
    let g:dein#install_log_filename = '~/.config/nvim/dein.log' " ask for log file
    call dein#install()
    let pluginsExist=1
  endif

call dein#end()
"}}}

" Plugin configuration {{{

" Easymotion {{{
function! MapEasymotionInit()
    let g:EasyMotion_smartcase = 1
    " bd for bidirectional :
    map <nowait><leader><leader> <Plug>(easymotion-bd-w)

    map <nowait><leader>f <Plug>(easymotion-bd-f)

    map <nowait><Leader>l <Plug>(easymotion-lineforward)
    map <nowait><Leader>j <Plug>(easymotion-j)
    map <nowait><Leader>k <Plug>(easymotion-k)
    map <nowait><Leader>h <Plug>(easymotion-linebackward)

    " beginning of words :
    map <nowait><leader>z <Plug>(easymotion-w)
    map <nowait><leader>Z <Plug>(easymotion-b)

    " end of words :
    map <nowait><leader>e <Plug>(easymotion-e)
    map <nowait><leader>E <Plug>(easymotion-ge)
endfunction
autocmd VimEnter * call MapEasymotionInit()
" }}}

" Smooth Scroll {{{
noremap <silent> <c-u> :call smooth_scroll#up(&scroll, 0, 2)<CR>
noremap <silent> <c-d> :call smooth_scroll#down(&scroll, 0, 2)<CR>
noremap <silent> <c-b> :call smooth_scroll#up(&scroll*2, 0, 4)<CR>
noremap <silent> <c-f> :call smooth_scroll#down(&scroll*2, 0, 4)<CR>
" }}}

" lightline {{{
" https://github.com/itchyny/lightline.vim/issues/87
let g:lightline = {'colorscheme': 'solarized'}

let g:lightline.active = {
    \ 'left': [ [ 'mode', 'paste' ],
    \           [ 'readonly', 'filename', 'modified' ] ],
    \ 'right': [ [ 'lineinfo' ],
    \            [ 'percent' ],
    \            [ 'absolutepath', 'filetype' ] ] }

" }}}

" fzf {{{
function! FzfOmniFiles()
    let is_git = system('git status')
    if v:shell_error
        :Files
    else
        :GitFiles
    endif
endfunction

nnoremap <leader>a :Ag<CR>
nnoremap <leader>c :Commands<CR>
nnoremap <C-p> :call FzfOmniFiles()<CR>

" fzf
" Hide statusline of terminal buffer
autocmd! FileType fzf
autocmd  FileType fzf set laststatus=0 noshowmode noruler
            \| autocmd BufLeave <buffer> set laststatus=2 noshowmode ruler

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Augmenting Ag command using fzf#vim#with_preview function
"   * fzf#vim#with_preview([[options], preview window, [toggle keys...]])
"     * For syntax-highlighting, Ruby and any of the following tools are required:
"       - Highlight: http://www.andre-simon.de/doku/highlight/en/highlight.php
"       - CodeRay: http://coderay.rubychan.de/
"       - Rouge: https://github.com/jneen/rouge
"
"   :Ag  - Start fzf with hidden preview window that can be enabled with "?" key
"   :Ag! - Start fzf in fullscreen and display the preview window above
command! -bang -nargs=* Ag
  \ call fzf#vim#ag(<q-args>,
  \                 <bang>0 ? fzf#vim#with_preview('up:60%')
  \                         : fzf#vim#with_preview('right:50%:hidden', '?'),
  \                 <bang>0)


" }}}

" SuperTab, SimpylFold & FastFold {{{
let g:SuperTabMappingForward = '<S-Tab>'
let g:SuperTabMappingBackward = '<Tab>'

let g:rainbow_active = 1 "0 if you want to enable it later via :RainbowToggle

" SimpylFold & FastFold
let g:SimpylFold_docstring_preview = 1
let g:SimpylFold_fold_docstring = 1
let g:SimpylFold_fold_import = 0
let g:fastfold_savehook = 1
let g:fastfold_fold_command_suffixes = []
let g:fastfold_fold_movement_commands = []
"}}}

" deoplete {{{
let g:deoplete#enable_at_startup = 1
let g:deoplete#auto_complete_delay = 0
let g:deoplete#sources#jedi#enable_cache = 1
let g:echodoc_enable_at_startup=1

let g:deoplete#file#enable_buffer_path=1
call deoplete#custom#source('buffer', 'mark', 'ℬ')
call deoplete#custom#source('omni', 'mark', '⌾')
call deoplete#custom#source('file', 'mark', '')
call deoplete#custom#source('jedi', 'mark', '')
call deoplete#custom#source('neosnippet', 'mark', '')
call deoplete#custom#source('ultisnips', 'mark', '')
call deoplete#custom#source('LanguageClient', 'mark', '')

" Debug mode
" call deoplete#enable_logging('DEBUG', '/tmp/deoplete.log')
" let g:deoplete#enable_profile = 0
" let g:deoplete#sources#jedi#debug_server = 0

" deoplete jedi for python
let g:deoplete#sources#jedi#server_timeout = 40 " extend time for large pkg
let g:deoplete#sources#jedi#show_docstring = 0  " show docstring in preview window
"autocmd CompleteDone * silent! pclose!
set completeopt-=preview  " if you don't want windows popup

"}}}

" Snippets {{{

" Register ultisnips in deoplete:
call deoplete#custom#source('ultisnips', 'matchers', ['matcher_fuzzy'])

" Choose Shift-Tab as expand for snippets:
let g:UltiSnipsExpandTrigger = "<S-Tab>" " default to <tab> that override tab deoplete completion

let g:UltiSnipsListSnippets = "<C-Tab>"
let g:UltiSnipsJumpForwardTrigger = "<C-n>"
let g:UltiSnipsJumpBackwardTrigger = "<C-p>"

let g:ultisnips_python_style = "google"

if (isdirectory(expand("$waxCraft_PATH/snippets/UltiSnips")))
  let g:UltiSnipsSnippetDirectories = [expand("$waxCraft_PATH/snippets/UltiSnips"), "UltiSnips"]
endif

" If wanted to use honza snippets with neosnippet engine:
" {{{
"if (isdirectory(expand("$HOME/.config/nvim/repos/github.com/honza/vim-snippets/")))
"  let g:neosnippet#snippets_directory = "$HOME/.config/nvim/repos/github.com/honza/vim-snippets/UltiSnips"
"endif
"" Choose Shift-Tab as expand for snippets:
"imap <S-Tab> <Plug>(neosnippet_expand_or_jump)
"smap <S-Tab> <Plug>(neosnippet_expand_or_jump)
"xmap <S-Tab> <Plug>(neosnippet_expand_target)
"" SuperTab like snippets behavior.
"imap <expr><TAB>
" \ pumvisible() ? "\<C-n>" :
" \ neosnippet#expandable_or_jumpable() ?
" \    "\<Plug>(neosnippet_expand_or_jump)" : "\<S-TAB>"
"" For conceal markers.
"if has('conceal')
"  set conceallevel=2 concealcursor=niv
"endif
"}}}
" }}}

" Pymode {{{
"let g:pymode_indent = 1 " pep8 indent
"let g:pymode_folding = 0 " disable folding to use SimpyFold
"let g:pymode_motion = 1
"" doc
"let g:pymode_doc = 1
"let g:pymode_doc_bind = 'K'
"" syntax (colors for self keyword for example)
"let g:pymode_syntax = 1
"let g:pymode_syntax_all = 1
"let g:pymode_syntax_slow_sync = 1 " slower syntax sync
"let g:pymode_trim_whitespaces = 0 " do not trim unused white spaces on save

"" Code completion :
"let g:pymode_rope = 0 " disable rope which is slow

"" Python code checking :
"let g:pymode_lint = 0  " disable it to use ALE
""let g:pymode_lint_on_write = 0
""let g:pymode_lint_checkers = ['flake8'] " pep8 code checker
""let g:syntastic_python_flake8_args='--ignore=E501'
""let g:pymode_lint_cwindow = 0  " do not open quickfix cwindows if errors

let g:jedi#documentation_command = "<leader>k"
let g:jedi#completions_enabled = 0
let g:jedi#force_py_version=3

map <Leader>o o__import__('pdb').set_trace()  # BREAKPOINT<C-c>
map <Leader>i o__import__('IPython').embed()  # Enter Ipython<C-c>

"}}}

" Lint ALE {{{
let g:ale_linter_aliases = {
    \ 'html': ['html', 'javascript', 'css'],
    \}

let g:ale_python_autopep8_options = '--max-line-length 160'

let g:ale_linters = {
            \ 'python': ['flake8'],
            \ 'text': ['alex', 'proselint'],
            \ 'html': ['htmlhint', 'proselint', 'writegood', 'tidy'],
            \}

let g:ale_fixers = {
            \ 'python': ['autopep8', 'isort', 'black'],
            \ 'html': ['prettier', 'eslint'],
            \ 'json': ['fixjson'],
            \}


" choice of ignored errors in ~/.config/flake8

"let g:ale_fix_on_save = 0  " always fix at save time

" go to previous error in current windows
map <nowait><silent> <A-q> <Plug>(ale_previous_wrap)

" go to next error in current windows
map <nowait><silent> <A-s> <Plug>(ale_next_wrap)

"map <nowait> <silent> <A-d> :lclose<CR>:bdelete<CR>

" autofix when in normal mode for all file and keep autopep8 for fix on range
" (i.e keep autopep8 for fix in visualmode)
noremap <leader>p :ALEFix <cr>
"}}}

" Autopep8 {{{
let g:autopep8_disable_show_diff=1 " disable show diff windows
"let g:autopep8_ignore="E501" " ignore line too long
let g:jedi#auto_close_doc = 1 " Automatically close preview windows upon leaving insert mode
vnoremap <leader>p :Autopep8<CR>
"}}}

" Jedi {{{
let g:jedi#completions_enabled = 0
let g:jedi#use_tabs_not_buffers = 0  " current default is 1.
let g:jedi#smart_auto_mappings = 0  " disable import completion keyword
let g:jedi#auto_close_doc = 1 " Automatically close preview windows upon leaving insert mode

let g:jedi#auto_initialization = 1 " careful, it set omnifunc that is unwanted
let g:jedi#show_call_signatures = 2  " do show the args of func in cmdline
" buggy:
"let g:jedi#auto_vim_configuration = 0  " set completeopt & rempas ctrl-C to Esc
" }}}

" AsyncRun {{{
" Quick run via <F10>
nnoremap <F10> :call <SID>compile_and_run()<CR>

augroup SPACEVIM_ASYNCRUN
    autocmd!
    " Automatically open the quickfix window
    autocmd User AsyncRunStart call asyncrun#quickfix_toggle(15, 1)
augroup END

function! s:compile_and_run()
    exec 'w'
    if &filetype == 'c'
        exec "AsyncRun! gcc % -o %<; time ./%<"
    elseif &filetype == 'cpp'
       exec "AsyncRun! g++ -std=c++11 % -o %<; time ./%<"
    elseif &filetype == 'java'
       exec "AsyncRun! javac %; time java %<"
    elseif &filetype == 'sh'
       exec "AsyncRun! time bash %"
    elseif &filetype == 'python'
       exec "AsyncRun! time python %"
    endif
endfunction
"}}}

" Table Mode {{{
" Restructured text compatible
au BufNewFile,BufRead *.rst let g:table_mode_header_fillchar='='
au BufNewFile,BufRead *.rst let g:table_mode_corner_corner='+'
au BufNewFile,BufRead *.py let g:table_mode_header_fillchar='='
au BufNewFile,BufRead *.py let g:table_mode_corner_corner='+'
au BufNewFile,BufRead *.md let g:table_mode_corner='|'
"}}}

" TagBar & UndoTree {{{
nnoremap <silent> <F9> :TagbarToggle<CR>
nnoremap <silent> <F8> :UndotreeToggle<CR>
nnoremap <silent> <F7> :NERDTreeToggle<CR>
"}}}

" Git {{{
  set signcolumn=yes
  let g:conflict_marker_enable_mappings = 0
  let g:gitgutter_sign_added = '•'
  let g:gitgutter_sign_modified = '•'
  let g:gitgutter_sign_removed = '•'
  let g:gitgutter_sign_removed_first_line = '•'
  let g:gitgutter_sign_modified_removed = '•'
" }}}

"}}}

" User Interface {{{
filetype plugin indent on
syntax enable

set background=dark
colorscheme solarized

set mouse=a             " Automatically enable mouse usage
set mousehide           " Hide the mouse cursor while typing
set number              " display line number column
set ruler               " Show the cursor position all the time
set cursorline          " Highlight the line of the cursor
set guicursor=          " disable cursor-styling
set noshowmode          " do not put a message on the cmdline for the mode ('insert', 'normal', ...)

set scrolljump=5        " Lines to scroll when cursor leaves screen
set scrolloff=3         " Have some context around the current line always on screen
set virtualedit=onemore " Allow for cursor beyond last character
set hidden              " Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
set foldenable          " Auto fold code
set splitright          " split at the right of current buffer (left default behaviour)
set splitbelow          " split at the below of current buffer (top default behaviour)
set relativenumber      " relative line number

let g:indentLine_color_gui = '#343d46'  " indent line color got indentLine plugin

" columns
set colorcolumn=80 " Show vertical bar at column 80
sign define dummy
execute 'sign place 9999 line=1 name=dummy buffer=' . bufnr('')

" transparent
hi Normal guibg=none ctermbg=none

" cmdline
set wildmenu                    " Show list instead of just completing
set wildmode=list:longest,full  " Command <Tab> completion, list matches, then longest common part, then all.

" Whitespace
set nowrap                " don't wrap lines
set tabstop=2 expandtab   " a tab is two spaces
set shiftwidth=2          " an autoindent (with <<) is two spaces
set list                  " show the following:
set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " Highlight problematic whitespace

set viewoptions=folds,cursor,unix,slash " Better Unix / Windows compatibility

if (!isdirectory(expand("$HOME/.vim/backup")))
  call system(expand("mkdir -p $HOME/.vim/backup"))
endif
if (!isdirectory(expand("$HOME/.vim/undo")))
  call system(expand("mkdir -p $HOME/.vim/undo"))
endif
set backup                              " Backups are nice ...
set backupdir=~/.vim/backup/
if has('persistent_undo')
  set undofile              " So is persistent undo ...
  set undolevels=1000       " Maximum number of changes that can be undone
  set undoreload=10000      " Maximum number lines to save for undo on a buffer reload
  set undodir=~/.vim/undo/
endif

" Searching
set ignorecase " searches are case insensitive...
set smartcase  " ... unless they contain at least one capital letter

" Clipboard
if has('clipboard')
  if has('unnamedplus')  " When possible use + register for copy-paste
    set clipboard=unnamed,unnamedplus
  else         " On mac and Windows, use * register for copy-paste
    set clipboard=unnamed
  endif
endif

"}}}

" Autocmd {{{
if has("autocmd")
  " Delete empty space from the end of lines on every save
  "au BufWritePre * :%s/\s\+$//e

  " Make sure all markdown files have the correct filetype set and setup
  " wrapping and spell check
  function! s:setupWrappingAndSpellcheck()
      set wrap
      set wrapmargin=2
      set textwidth=80
      set spell
  endfunction
  au BufRead,BufNewFile *.{md,md.erb,markdown,mdown,mkd,mkdn,txt} setf markdown | call s:setupWrappingAndSpellcheck()

  set expandtab

  " Treat JSON files like JavaScript
  au BufNewFile,BufRead *.json set ft=javascript

  " Python
  au BufRead,BufNewFile *.py setlocal filetype=python
  au BufRead,BufNewFile *.py setlocal shiftwidth=4 tabstop=4 softtabstop=4
  au BufRead,BufNewFile *.py setlocal textwidth=79

  " Other
  au BufNewFile,BufRead *.snippets set filetype=snippets foldmethod=marker
  au BufNewFile,BufRead *.nix set filetype=nix
  au BufNewFile,BufRead *.sh set filetype=sh foldlevel=0 foldmethod=marker

  au BufNewFile,BufRead Filetype vim setlocal tabstop=2 foldmethod=marker

  au BufNewFile,BufRead *.cmake set filetype=cmake
  au BufNewFile,BufRead CMakeLists.txt set filetype=cmake

  au BufNewFile,BufRead *.json set filetype=json

  au BufNewFile,BufRead *.txt set filetype=sh

  " html:
  au BufNewFile,BufRead *.html set shiftwidth=2 tabstop=2 softtabstop=2
  au BufNewFile,BufRead *.html set foldmethod=syntax expandtab nowrap

  " Git
  au Filetype gitcommit setlocal spell textwidth=72

  " Switch to the current file directory when a new buffer is opened
  au BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif

endif

"}}}

" Times choices:
set ttimeoutlen=10
set timeoutlen=500
" improve quick escape from insertion mode:
augroup FastEscape
  autocmd!
  au InsertEnter * set timeoutlen=0
  au InsertLeave * set timeoutlen=500
augroup END

" Mappings {{{

" Behaviour fixes {{{

" quick escape:
map <nowait> <Esc> <C-c>
cmap <nowait> <Esc> <C-c>

" ALT + backspace in cmd to delete word, like in terminal
cmap <a-bs> <c-w>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>

" Nvim Terminal
" Make escape work in the Neovim terminal.
tnoremap <Esc> <C-\><C-n>

" }}}

" map open terminal
map <nowait> <A-t> :vsplit \| terminal <CR>

" clear the search highlight
nnoremap <leader>; :nohl<cr>

" select all of current paragraph with enter:
nnoremap <return> vip

" Are remapped by vim-tmux-navigator
" easier navigation between split windows
"nnoremap <c-j> <c-w>j
"nnoremap <c-k> <c-w>k
"nnoremap <c-h> <c-w>h
"nnoremap <c-l> <c-w>l

" Terminal mode:
tnoremap <c-h> <c-\><c-n><c-w>h
tnoremap <c-j> <c-\><c-n><c-w>j
tnoremap <c-k> <c-\><c-n><c-w>k
tnoremap <c-l> <c-\><c-n><c-w>l

" Insert mode:
inoremap <c-h> <c-\><c-n><c-w>h
inoremap <c-j> <c-\><c-n><c-w>j
inoremap <c-k> <c-\><c-n><c-w>k
inoremap <c-l> <c-\><c-n><c-w>l

" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null

" Buffers {{{
" --> About buffers switch
" Little snippet to get all alt key mapping functional :
" works for alt-a .. alt-z
for i in range(97,122)
  let c = nr2char(i)
  exec "map \e".c." <A-".c.">"
  exec "map! \e".c." <A-".c.">"
endfor

map <nowait> <A-a> :bp<cr>
map <nowait> <A-z> :bn<cr>

" buffer delete without closing windows :
nmap <silent> <A-d> :bp\|bd! #<CR>
"}}}

" Split windows
map <nowait> <A-e> :vs<cr>
map <nowait> <A-r> :sp<cr>

" About folding open and close :
nnoremap <Space> za
vnoremap <Space> za

" qwerty --> azerty {{{
noremap w z
noremap z w

nnoremap ww zz
nnoremap zz ww

" Some motions
vnoremap ww zz
vnoremap wt zt
vnoremap wb zb

" --> Folding : closing/opening all opened foldings :
nnoremap wM zR
vnoremap wM zR
nnoremap wm zM
vnoremap wm zM

" --> Folding : movements (next / prec) :
nnoremap wj zj
vnoremap wj zj
nnoremap wk zk
vnoremap wk zk

function! InitMovementMap()
    if mapcheck("z", "N") != ""
        unmap z
    endif
    noremap <nowait> z w
endfunction
autocmd VimEnter * call InitMovementMap()
noremap <nowait> z w
noremap <nowait> Z b
noremap <nowait> e e
noremap <nowait> E ge
"}}}

" copy to clipboard :
vnoremap <Leader>y "+y

noremap H ^
noremap L g_

" source config
if !exists('*ActualizeInit')
  function! ActualizeInit()
    call dein#recache_runtimepath()
    source ${HOME}/.config/nvim/init.vim
  endfunction
endif
map <F12> :call ActualizeInit()<cr>
"}}}

" Custom Functions {{{
" Profile vim
function! StartProfiling()
  execute ":profile start /tmp/neovim.profile"
  execute ":profile func *"
  execute ":profile file *"
  let g:profiling=1
endfunction

function! EndProfiling()
  execute ":profile pause"
  let g:profiling=0
endfunction

let g:profiling=0
function! ToggleProfiling()
  if g:profiling == 0
    call StartProfiling()
  else
    call EndProfiling()
  endif
endfunction

function! ToggleVerbose()
    if !&verbose
        set verbosefile=/tmp/vim_verbose.log
        set verbose=15
    else
        set verbose=0
        set verbosefile=
    endif
endfunction
"}}}

" local config
if !empty(glob("~/.nvimrc_local"))
    source ~/.nvimrc_local
endif
