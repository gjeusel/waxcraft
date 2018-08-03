"/ vim: set sw=4 ts=4 sts=4 et tw=78 foldmarker={,} foldlevel=0 foldmethod=marker spell:

" Install dein :
" curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
" sh installer.sh ~/.vim/bundle/

if &compatible
  set nocompatible
endif
set runtimepath+=~/.vim/bundle/repos/github.com/Shougo/dein.vim/
let mapleader=","

" Plugins dein declarations {

" path to where to store plugins:
if dein#load_state('~/.vim/bundle')
  call dein#begin('~/.vim/bundle')

  " path to plugin manager:
  call dein#add('~/.vim/bundle/repos/github.com/Shougo/dein.vim/')

  " tmux navigation in love with vim
  call dein#add('christoomey/vim-tmux-navigator')

  " User Interface {
  call dein#add('itchyny/lightline.vim')
  call dein#add('ap/vim-buftabline')
  call dein#add('altercation/vim-colors-solarized')

  " Syntax highlight
  call dein#add('LnL7/vim-nix')  " for .nix
  call dein#add('cespare/vim-toml')  " syntax for .toml
  call dein#add('luochen1990/rainbow')  " embed parenthesis colors

  call dein#add('airblade/vim-gitgutter') " column sign for git changes
  call dein#add('rhysd/conflict-marker.vim') " conflict markers for vimdiff
  "}

  " Generic tools {
  call dein#add('terryma/vim-smooth-scroll')  " smooth scroll

  call dein#add('kien/ctrlp.vim') " Fuzzy file finder
  "call dein#add('junegunn/fzf.vim')  " asynchronous fuzzy finder, should replace ctrlp if ever to work with huuge projects

  call dein#add('tpope/vim-fugitive') " Git wrapper for vim
  call dein#add('tpope/vim-surround') " change surrounding easily
  call dein#add('tpope/vim-repeat') " better action repeat for vim-surround with .

  "call dein#add('jiangmiao/auto-pairs') " auto pair
  call dein#add('godlygeek/tabular') " tabularize
  call dein#add('dhruvasagar/vim-table-mode')  " to easily create tables.
  call dein#add('majutsushi/tagbar') " browsing the tags, require ctags
  call dein#add('scrooloose/nerdcommenter')  " easy comments
  call dein#add('mbbill/undotree')  " visualize undo tree

  call dein#add('vim-scripts/loremipsum')  " dummy text generator (:Loremipsum [number of words])

  " Snippets
  call dein#add('SirVer/ultisnips') " snippets engine handle
  call dein#add('honza/vim-snippets') " those are the snippets

  call dein#add('Konfekt/FastFold')  " update folds only when needed, otherwise folds slowdown vim

  call dein#add('easymotion/vim-easymotion')  " easymotion when fedup to think
  call dein#add('skywind3000/asyncrun.vim')  " run async shell commands
  "}

  " Completion engine {
  call dein#add('ervandew/supertab') " tab handler for better autocompletion

  call dein#add('Shougo/deoplete.nvim')  " async engine
  call dein#add('carlitux/deoplete-ternjs')  " for javascript
  call dein#add('zchee/deoplete-jedi') " for python
  call dein#add('zchee/deoplete-go') " for golang
  call dein#add('Shougo/neco-vim') " for vim
  call dein#add('mattn/emmet-vim') " for html - CSS - javascript

  " }

  " Syntax Check {
  call dein#add('Shougo/neco-syntax') " syntax source for neocomplete
  call dein#add('w0rp/ale')  " general asynchronous syntax checker
  call dein#add('wooorm/alex')  " general syntax checker
  call dein#add('yaniswang/HTMLHint')  " html
  call dein#add('eslint/eslint')  " js
  "}

  " Specific Languages {

  " Python
  call dein#add('tmhedberg/SimpylFold')  " better folds
  call dein#add('python-mode/python-mode')
  call dein#add('davidhalter/jedi-vim')
  call dein#add('tell-k/vim-autopep8')
  "call dein#add('nvie/vim-flake8')
  "}

  " Html {
  call dein#add('tmhedberg/matchit')  " % for matching tag
  call dein#add('rstacruz/sparkup')  " for html auto generation
  "}

  call dein#end()
  call dein#save_state()
endif
"}

" Dein cfg {
" ask for log file
let g:dein#install_log_filename = '~/.vim/dein.log'

"If you want to install not installed plugins on startup.
if dein#check_install()
call dein#install()
endif
"}

" Plugin configuration{

" Tabular {
function! MapTabularInit()
    noremap <Leader>t :Tabularize /
    vnoremap <Leader>t :Tabularize /
endfunction
autocmd VimEnter * call MapTabularInit()
"}

" Easymotion {
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
" }

" Smooth Scroll {
noremap <silent> <c-u> :call smooth_scroll#up(&scroll, 0, 2)<CR>
noremap <silent> <c-d> :call smooth_scroll#down(&scroll, 0, 2)<CR>
noremap <silent> <c-b> :call smooth_scroll#up(&scroll*2, 0, 4)<CR>
noremap <silent> <c-f> :call smooth_scroll#down(&scroll*2, 0, 4)<CR>
" }

" lightline {
" https://github.com/itchyny/lightline.vim/issues/87
let g:lightline = {'colorscheme': 'solarized'}

let g:lightline.active = {
    \ 'left': [ [ 'mode', 'paste' ],
    \           [ 'readonly', 'filename', 'modified' ] ],
    \ 'right': [ [ 'lineinfo' ],
    \            [ 'percent' ],
    \            [ 'absolutepath', 'filetype' ] ] }

" }

" CtrlP {
let g:ctrlp_custom_ignore = {
    \ 'dir':  '\v(\v[\/]\.(git|hg|svn)$)|(test/data/pgdb)|(\v\.egg-info)',
    \ 'file': '\v\.(exe|so|dll|pyc)$',
    \ }
let g:ctrlp_user_command = 'ag %s -l -U --nocolor -g ""'
"}

" SuperTab, SimpylFold & FastFold {
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
"}

" deoplete {

" Debug mode
"call deoplete#enable_logging('DEBUG', '/tmp/deoplete.log')
let g:deoplete#enable_profile = 0
let g:deoplete#sources#jedi#debug_server = 0

let g:deoplete#enable_at_startup = 1
let g:deoplete#sources#jedi#server_timeout = 40 " extend time for large pkg
let g:deoplete#sources#jedi#show_docstring = 0  " show docstring in preview window
"autocmd CompleteDone * silent! pclose!
"set completeopt-=preview  " if you don't want windows popup

" compatibility deoplete & ultisnipts:
call deoplete#custom#source('ultisnips', 'matchers', ['matcher_fuzzy'])

" Fix deoplete & ultisnips problem with <tab> completion :
let g:UltiSnipsExpandTrigger = "<S-Tab>" " default to <tab> that override tab deoplete completion

let g:UltiSnipsListSnippets = "<c-tab>"
let g:UltiSnipsJumpForwardTrigger = "<c-j>"
let g:UltiSnipsJumpBackwardTrigger = "<c-k>"

"}

" Pymode {
let g:pymode_indent = 1 " pep8 indent
let g:pymode_folding = 0 " disable folding to use SimpyFold
let g:pymode_motion = 1
" doc
let g:pymode_doc = 1
let g:pymode_doc_bind = 'K'
" syntax (colors for self keyword for example)
let g:pymode_syntax = 1
let g:pymode_syntax_all = 1
let g:pymode_syntax_slow_sync = 1 " slower syntax sync
let g:pymode_trim_whitespaces = 0 " do not trim unused white spaces on save

" Code completion :
let g:pymode_rope = 0 " disable rope which is slow

" Python code checking :
let g:pymode_lint = 0  " disable it to use ALE
"let g:pymode_lint_on_write = 0
"let g:pymode_lint_checkers = ['flake8'] " pep8 code checker
"let g:syntastic_python_flake8_args='--ignore=E501'
"let g:pymode_lint_cwindow = 0  " do not open quickfix cwindows if errors

map <Leader>o o__import__('pdb').set_trace()  # BREAKPOINT<C-c>
map <Leader>i o__import__('IPython').embed()  # Enter Ipython<C-c>

"}

" Lint ALE {
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
"}

" Autopep8 {
let g:autopep8_disable_show_diff=1 " disable show diff windows
"let g:autopep8_ignore="E501" " ignore line too long
let g:jedi#auto_close_doc = 1 " Automatically close preview windows upon leaving insert mode
vnoremap <leader>p :Autopep8<CR>
"}

" Jedi {
let g:jedi#completions_enabled = 0
let g:jedi#use_tabs_not_buffers = 0  " current default is 1.
let g:jedi#smart_auto_mappings = 0  " disable import completion keyword
let g:jedi#auto_close_doc = 1 " Automatically close preview windows upon leaving insert mode

let g:jedi#auto_initialization = 1 " careful, it set omnifunc that is unwanted
let g:jedi#show_call_signatures = 2  " do show the args of func in cmdline
" buggy:
"let g:jedi#auto_vim_configuration = 0  " set completeopt & rempas ctrl-C to Esc
" }

" AsyncRun {
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
"}

" Table Mode {
" Restructured text compatible
au BufNewFile,BufRead *.rst let g:table_mode_header_fillchar='='
au BufNewFile,BufRead *.rst let g:table_mode_corner_corner='+'
au BufNewFile,BufRead *.py let g:table_mode_header_fillchar='='
au BufNewFile,BufRead *.py let g:table_mode_corner_corner='+'
au BufNewFile,BufRead *.md let g:table_mode_corner='|'
"}

" TagBar & UndoTree {
nnoremap <silent> <F9> :TagbarToggle<CR>
nnoremap <silent> <F8> :UndotreeToggle<CR>
"}

" }

" User Interface {
filetype plugin indent on
syntax enable
set background=dark
colorscheme solarized

set mouse=a             " Automatically enable mouse usage
set mousehide           " Hide the mouse cursor while typing
set number              " display line number column
set ruler               " Show the cursor position all the time
set cursorline          " Highlight the line of the cursor
set guicursor=
set scrolljump=5        " Lines to scroll when cursor leaves screen
set scrolloff=3         " Have some context around the current line always on screen
set virtualedit=onemore " Allow for cursor beyond last character
set hidden              " Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
set foldenable          " Auto fold code
set splitright          " split at the right of current buffer (left default behaviour)
set splitbelow          " split at the below of current buffer (top default behaviour)
set relativenumber                                                                                " relative line number

" columns
set colorcolumn=80 " Show vertical bar at column 80
sign define dummy
execute 'sign place 9999 line=1 name=dummy buffer=' . bufnr('')
highlight SignColumn        cterm=none ctermbg=none
highlight SignifySignAdd    cterm=bold ctermbg=none ctermfg=64
highlight SignifySignDelete cterm=none ctermbg=none ctermfg=136
highlight SignifySignChange cterm=none ctermbg=none ctermfg=124
highlight Folded                       ctermbg=none
highlight foldcolumn                   ctermbg=none ctermfg=none
highlight TermCursorNC      cterm=none ctermbg=14   ctermfg=none

" transparent
hi Normal guibg=none ctermbg=none

" cmdline
set wildmenu                    " Show list instead of just completing
set wildmode=list:longest,full  " Command <Tab> completion, list matches, then longest common part, then all.

" Whitespace
set nowrap                        " don't wrap lines
set tabstop=4                     " a tab is two spaces
set shiftwidth=4                  " an autoindent (with <<) is two spaces
set list " show the following:
set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " Highlight problematic whitespace

" Backup
" Initialize directories {
function! InitializeDirectories()
    let parent = $HOME
    let prefix = 'vim'
    let dir_list = {
                \ 'backup': 'backupdir',
                \ 'views': 'viewdir',
                \ 'swap': 'directory' }

    if has('persistent_undo')
        let dir_list['undo'] = 'undodir'
    endif

    let common_dir = parent . '/.' . prefix

    for [dirname, settingname] in items(dir_list)
        let directory = common_dir . dirname . '/'
        if exists("*mkdir")
            if !isdirectory(directory)
                call mkdir(directory)
            endif
        endif
        if !isdirectory(directory)
            echo "Warning: Unable to create backup directory: " . directory
            echo "Try: mkdir -p " . directory
        else
            let directory = substitute(directory, " ", "\\\\ ", "g")
            exec "set " . settingname . "=" . directory
        endif
    endfor
endfunction
call InitializeDirectories()
" }

set viewoptions=folds,cursor,unix,slash " Better Unix / Windows compatibility
set backup                              " Backups are nice ...
if has('persistent_undo')
  set undofile                          " So is persistent undo ...
  set undolevels=1000                   " Maximum number of changes that can be undone
  set undoreload=10000                  " Maximum number lines to save for undo on a buffer reload
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

" Autocmd
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
  au BufRead,BufNewFile *.py setlocal shiftwidth=4
  au BufRead,BufNewFile *.py setlocal tabstop=4
  au BufRead,BufNewFile *.py setlocal softtabstop=4
  au BufRead,BufNewFile *.py setlocal textwidth=79

  " other
  au BufNewFile,BufRead *.cuf set filetype=fortran
  au BufNewFile,BufRead *.nml set filetype=fortran
  au BufNewFile,BufRead *.namelist set filetype=fortran
  au BufNewFile,BufRead *.nix set filetype=nix
  au BufNewFile,BufRead *.sh set filetype=sh foldlevel=0 foldmethod=marker
  au BufNewFile,BufRead *.vimrc* set filetype=vim
  au BufNewFile,BufRead *.vim set filetype=vim tabstop=2
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

"}

" Times choices:
set ttimeoutlen=10
set timeoutlen=500
" improve quick escape from insertion mode:
augroup FastEscape
  autocmd!
  au InsertEnter * set timeoutlen=0
  au InsertLeave * set timeoutlen=500
augroup END

" Key (re)Mappings {

" Behaviour fixes {

" quick escape:
map <nowait> <Esc> <C-c>
cmap <nowait> <Esc> <C-c>

" ALT + backspace in cmd to delete word, like in terminal
cmap <a-bs> <c-w>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>

" map open terminal
map <nowait> <A-t> :vsplit \| terminal <CR>

" Nvim Terminal
" Make escape work in the Neovim terminal.
tnoremap <Esc> <C-\><C-n>

" }

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

" map Ctrl+S to :w
noremap <silent> <C-S>  :update<CR>
vnoremap <silent> <C-S>  :update<CR>
inoremap <silent> <C-S>  :update<CR>

" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null

" Buffers {
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
"}

" Split windows
map <nowait> <A-e> :vs %<cr>
map <nowait> <A-r> :sp %<cr>

" Folding binds : {
" --> About folding open and close :
nnoremap <Space> za
vnoremap <Space> za
" }

" qwerty --> azerty {

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
"}

" copy to clipboard :
vnoremap <Leader>y "+y

" source config
if !exists('*ActualizeInit')
  function! ActualizeInit()
    "call dein#recache_runtimepath()
    source ${HOME}/.config/nvim/init.vim
  endfunction
endif
map <F12> :call ActualizeInit()<cr>

" Profile vim {
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
"}

function! ToggleVerbose()
    if !&verbose
        set verbosefile=/tmp/vim_verbose.log
        set verbose=15
    else
        set verbose=0
        set verbosefile=
    endif
endfunction

"" see logs of update
"command! DeinUpdate  call s:dein_update()
"function! s:dein_update()
"  call dein#update()
"  Denite dein/log:!
"endfunction

"}
