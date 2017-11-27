" vim: set sw=4 ts=4 sts=4 et tw=78 foldmarker={,} foldlevel=0 foldmethod=marker spell:

call plug#begin('~/.config/nvim/plugged')

Plug 'AndrewRadev/splitjoin.vim'
Plug 'danchoi/ri.vim'
Plug 'danro/rename.vim'
Plug 'godlygeek/tabular'
Plug 'isRuslan/vim-es6'
Plug 'janko-m/vim-test'
Plug 'jeffkreeftmeijer/vim-numbertoggle'
Plug 'kana/vim-textobj-user'
Plug 'kien/ctrlp.vim'
Plug 'mileszs/ack.vim'
Plug 'morhetz/gruvbox'
Plug 'nelstrom/vim-textobj-rubyblock'
Plug 'neomake/neomake'
Plug 'rainerborene/vim-reek'
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

Plug 'majutsushi/tagbar'
Plug 'scrooloose/nerdcommenter'
Plug 'rhysd/conflict-marker.vim'
Plug 'vim-scripts/sessionman.vim'
Plug 'mbbill/undotree'
Plug 'vim-scripts/restore_view.vim'
Plug 'bling/vim-bufferline'
Plug 'easymotion/vim-easymotion'
Plug 'flazz/vim-colorschemes'

Plug 'Shougo/neco-vim'
Plug 'Shougo/neoinclude.vim'
Plug 'Shougo/neco-syntax'
Plug 'Shougo/vimshell.vim'
Plug 'ujihisa/neco-look'
Plug 'Shougo/context_filetype.vim'
Plug 'Shougo/echodoc.vim'
Plug 'altercation/vim-colors-solarized'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'zchee/deoplete-jedi'
Plug 'zchee/deoplete-go'

Plug 'TFenby/python-mode', { 'branch' : 'develop' }
Plug 'LnL7/vim-nix'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'Konfekt/FastFold'
Plug 'Konfekt/FoldText'
Plug 'SirVer/ultisnips'
Plug 'davidhalter/jedi-vim'

call plug#end()

runtime macros/matchit.vim          " Enables % to cycle through `if/else/endif`, recognizing Ruby blocks, etc.

set number
set ruler                              " Show the cursor position all the time
set colorcolumn=80                     " Show vertical bar at column 80
set cursorline                         " Highlight the line of the cursor
set showcmd                            " Show partial commands below the status line
set shell=bash                         " Avoids munging PATH under zsh
let g:is_bash=1                        " Default shell syntax
set scrolloff=3                        " Have some context around the current line always
                                       " on screen
set noerrorbells visualbell t_vb=      " Disable bell
set hidden                             " Allow backgrounding buffers without writing
                                       " them, and remember marks/undo for backgrounded
                                       " buffers
set backupdir=~/.config/nvim/_backup   " where to put backup files
set directory=~/.config/nvim/_temp     " where to put swap files
set inccommand=nosplit                 " incremental substitute

" Whitespace
set nowrap                        " don't wrap lines
set tabstop=2                     " a tab is two spaces
set shiftwidth=2                  " an autoindent (with <<) is two spaces
set expandtab                     " use spaces, not tabs

" Searching
set ignorecase                    " searches are case insensitive...
set smartcase                     " ... unless they contain at least one capital letter

function! s:setupWrappingAndSpellcheck()
  set wrap
  set wrapmargin=2
  set textwidth=80
  set spell
endfunction

" Toggle relative numbers
nnoremap <C-n> :let &rnu=!&rnu<CR>

if has("autocmd")
  " Delete empty space from the end of lines on every save
  au BufWritePre * :%s/\s\+$//e

  " Make sure all markdown files have the correct filetype set and setup
  " wrapping and spell check
  au BufRead,BufNewFile *.{md,md.erb,markdown,mdown,mkd,mkdn,txt} setf markdown | call s:setupWrappingAndSpellcheck()

  " Spellcheck
  au BufRead,BufNewFile *.feature setlocal spell

  " Treat JSON files like JavaScript
  au BufNewFile,BufRead *.json set ft=javascript

  " Remember last location in file, but not for commit messages.
  " see :help last-position-jump
  au BufReadPost * if &filetype !~ '^git\c' && line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g`\"" | endif

  " Encrypted Yaml
  au BufRead,BufNewFile *.{yml.enc} setlocal filetype=yaml

  au BufRead,BufNewFile *.{inky} setlocal filetype=html

  " python
  au BufRead,BufNewFile *.py setlocal filetype=py
  au BufRead,BufNewFile *.py setlocal shiftwidth=4
  au BufRead,BufNewFile *.py setlocal tabstop=4
  au BufRead,BufNewFile *.py setlocal softtabstop=4
  au BufRead,BufNewFile *.py setlocal textwidth=79

  " Git
  au Filetype gitcommit setlocal spell textwidth=72

  au BufWritePost * Neomake
endif

" clear the search buffer when hitting return
:nnoremap <leader>; :nohlsearch<cr>

let mapleader=","

" paste lines from unnamed register and fix indentation
nmap <leader>p pV`]=
nmap <leader>P PV`]=

map <leader>ga :CtrlP app<cr>
map <leader>gv :CtrlP app/views<cr>
map <leader>gc :CtrlP app/controllers<cr>
map <leader>gm :CtrlP app/models<cr>
map <leader>gh :CtrlP app/helpers<cr>
map <leader>gj :CtrlP app/assets/javascripts<cr>
map <leader>gf :CtrlP features<cr>
map <leader>gs :CtrlP spec<cr>
map <leader>gt :CtrlP test<cr>
map <leader>gl :CtrlP lib<cr>
map <leader>f :CtrlP ./<cr>
map <leader>b :CtrlPBuffer<cr>
map <leader>gd :e db/schema.rb<cr>
map <leader>gr :e config/routes.rb<cr>
map <leader>gg :e Gemfile<cr>
map <leader>s :A<CR>
map <leader>v :AV<CR>

" vim-test
nmap <silent> <leader>t :TestNearest<CR>
nmap <silent> <leader>T :TestFile<CR>
nmap <silent> <leader>l :TestLast<CR>
nmap <silent> <leader>g :TestVisit<CR>
let test#strategy="neovim"

set wildignore+=tmp/**
set wildignore+=*/vendor/*
set wildignore+=*/plugged/*

nnoremap <leader><leader> <c-^>

" easier navigation between split windows
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

" map Ctrl+S to :w
noremap <silent> <C-S>  :update<CR>
vnoremap <silent> <C-S>  :update<CR>
inoremap <silent> <C-S>  :update<CR>

" Ack
let g:ackprg="ack-grep -H --nocolor --nogroup --column"
nmap <leader>a :Ack ""<Left>
nmap <leader>A :Ack <C-r><C-w>

" Airline
let g:airline_left_sep='›'  " Slightly fancier than '>'
let g:airline_right_sep='‹' " Slightly fancier than '<'
let g:airline_section_x=""
let g:airline_section_y=""
let g:airline_section_z="%l/%L %-3.c"

" Reek
let g:reek_on_loading = 0
let g:reek_line_limit = 1000 " Don't check files with more than 1000 lines

" Nvim Terminal
" Make escape work in the Neovim terminal.
tnoremap <Esc> <C-\><C-n>

" Make navigation into and out of Neovim terminal splits nicer.
tnoremap <C-h> <C-\><C-N><C-w>h
tnoremap <C-j> <C-\><C-N><C-w>j
tnoremap <C-k> <C-\><C-N><C-w>k
tnoremap <C-l> <C-\><C-N><C-w>l

" I like relative numbering when in normal mode.
autocmd TermOpen * setlocal conceallevel=0 colorcolumn=0 relativenumber

" Prefer Neovim terminal insert mode to normal mode.
autocmd BufEnter term://* startinsert

" Ruby on Rails
let g:rubycomplete_rails = 1

" Color scheme
"let g:gruvbox_contrast_dark="soft"
set background=dark
colorscheme gruvbox
let g:airline_theme="gruvbox"

"
"
"#########################################################
"                   SPF13
"
" General {

    set background=dark         " Assume a dark background

    " if !has('gui')
        "set term=$TERM          " Make arrow and other keys work
    " endif
    filetype plugin indent on   " Automatically detect file types.
    syntax on                   " Syntax highlighting
    set mouse=a                 " Automatically enable mouse usage
    set mousehide               " Hide the mouse cursor while typing
    scriptencoding utf-8

    if has('clipboard')
        if has('unnamedplus')  " When possible use + register for copy-paste
            set clipboard=unnamed,unnamedplus
        else         " On mac and Windows, use * register for copy-paste
            set clipboard=unnamed
        endif
    endif

    " Most prefer to automatically switch to the current file directory when
    " a new buffer is opened; to prevent this behavior, add the following to
    " your .vimrc.before.local file:
    "   let g:spf13_no_autochdir = 1
    if !exists('g:spf13_no_autochdir')
        autocmd BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif
        " Always switch to the current file directory
    endif

    "set autowrite                       " Automatically write a file when leaving a modified buffer
    set shortmess+=filmnrxoOtT          " Abbrev. of messages (avoids 'hit enter')
    set viewoptions=folds,options,cursor,unix,slash " Better Unix / Windows compatibility
    set virtualedit=onemore             " Allow for cursor beyond last character
    set history=1000                    " Store a ton of history (default is 20)
    set spell                           " Spell checking on
    set hidden                          " Allow buffer switching without saving
    set iskeyword-=.                    " '.' is an end of word designator
    set iskeyword-=#                    " '#' is an end of word designator
    set iskeyword-=-                    " '-' is an end of word designator

    " Instead of reverting the cursor to the last position in the buffer, we
    " set it to the first line when editing a git commit message
    au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])

    " http://vim.wikia.com/wiki/Restore_cursor_to_file_position_in_previous_editing_session
    " Restore cursor to file position in previous editing session
    " To disable this, add the following to your .vimrc.before.local file:
    "   let g:spf13_no_restore_cursor = 1
    if !exists('g:spf13_no_restore_cursor')
        function! ResCur()
            if line("'\"") <= line("$")
                silent! normal! g`"
                return 1
            endif
        endfunction

        augroup resCur
            autocmd!
            autocmd BufWinEnter * call ResCur()
        augroup END
    endif

    " Setting up the directories {
        set backup                  " Backups are nice ...
        if has('persistent_undo')
            set undofile                " So is persistent undo ...
            set undolevels=1000         " Maximum number of changes that can be undone
            set undoreload=10000        " Maximum number lines to save for undo on a buffer reload
        endif

        " To disable views add the following to your .vimrc.before.local file:
        "   let g:spf13_no_views = 1
        if !exists('g:spf13_no_views')
            " Add exclusions to mkview and loadview
            " eg: *.*, svn-commit.tmp
            let g:skipview_files = [
                \ '\[example pattern\]'
                \ ]
        endif
    " }

" }

" Vim UI {

set tabpagemax=15               " Only show 15 tabs
set showmode                    " Display the current mode

set cursorline                  " Highlight current line

highlight clear SignColumn      " SignColumn should match background
highlight clear LineNr          " Current line number row will have same background color in relative mode
"highlight clear CursorLineNr    " Remove highlight color from current line number

let g:solarized_termcolors=256
"let g:solarized_termtrans=1
let g:solarized_contrast="normal"
let g:solarized_visibility="normal"
color solarized             " Load a colorscheme

set backspace=indent,eol,start  " Backspace for dummies
set linespace=0                 " No extra spaces between rows
set number                      " Line numbers on
set showmatch                   " Show matching brackets/parenthesis
set incsearch                   " Find as you type search
set hlsearch                    " Highlight search terms
set winminheight=0              " Windows can be 0 line high
set ignorecase                  " Case insensitive search
set smartcase                   " Case sensitive when uc present
set wildmenu                    " Show list instead of just completing
set wildmode=list:longest,full  " Command <Tab> completion, list matches, then longest common part, then all.
set whichwrap=b,s,h,l,<,>,[,]   " Backspace and cursor keys wrap too
set scrolljump=5                " Lines to scroll when cursor leaves screen
set scrolloff=3                 " Minimum lines to keep above and below cursor
set foldenable                  " Auto fold code
set list
set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " Highlight problematic whitespace
"}

" Formatting {

    set nowrap                      " Do not wrap long lines
    set autoindent                  " Indent at the same level of the previous line
    set shiftwidth=4                " Use indents of 4 spaces
    set expandtab                   " Tabs are spaces, not tabs
    set tabstop=4                   " An indentation every four columns
    set softtabstop=4               " Let backspace delete indent
    set nojoinspaces                " Prevents inserting two spaces after punctuation on a join (J)
    set splitright                  " Puts new vsplit windows to the right of the current
    set splitbelow                  " Puts new split windows to the bottom of the current
    "set matchpairs+=<:>             " Match, to be used with %
    set pastetoggle=<F12>           " pastetoggle (sane indentation on pastes)
    "set comments=sl:/*,mb:*,elx:*/  " auto format comment blocks
    " Remove trailing whitespaces and ^M chars
    " To disable the stripping of whitespace, add the following to your
    " .vimrc.before.local file:
    "   let g:spf13_keep_trailing_whitespace = 1
    autocmd FileType c,cpp,java,go,php,javascript,puppet,python,rust,twig,xml,yml,perl,sql autocmd BufWritePre <buffer> if !exists('g:spf13_keep_trailing_whitespace') | call StripTrailingWhitespace() | endif
    "autocmd FileType go autocmd BufWritePre <buffer> Fmt
    autocmd BufNewFile,BufRead *.html.twig set filetype=html.twig
    autocmd FileType haskell,puppet,ruby,yml setlocal expandtab shiftwidth=2 softtabstop=2
    " preceding line best in a plugin but here for now.

    autocmd BufNewFile,BufRead *.coffee set filetype=coffee

    " Workaround vim-commentary for Haskell
    autocmd FileType haskell setlocal commentstring=--\ %s
    " Workaround broken colour highlighting in Haskell
    autocmd FileType haskell,rust setlocal nospell

" }

" Key (re)Mappings {

    " Shortcuts
    " Change Working Directory to that of the current file
    cmap cwd lcd %:p:h
    cmap cd. lcd %:p:h

    " Visual shifting (does not exit Visual mode)
    vnoremap < <gv
    vnoremap > >gv

    " Allow using the repeat operator with a visual selection (!)
    " http://stackoverflow.com/a/8064607/127816
    vnoremap . :normal .<CR>

    " For when you forget to sudo.. Really Write the file.
    cmap w!! w !sudo tee % >/dev/null

    " Map <Leader>ff to display all lines with keyword under cursor
    " and ask which one to jump to
    nmap <Leader>ff [I:let nr = input("Which one: ")<Bar>exe "normal " . nr ."[\t"<CR>

    " Easier formatting, justify the text
    nnoremap <silent> <leader>q gwip
"}

"" Plugins {

"    " TextObj Sentence {
"        if count(g:spf13_bundle_groups, 'writing')
"            augroup textobj_sentence
"              autocmd!
"              autocmd FileType markdown call textobj#sentence#init()
"              autocmd FileType textile call textobj#sentence#init()
"              autocmd FileType text call textobj#sentence#init()
"            augroup END
"        endif
"    " }

"    " TextObj Quote {
"        if count(g:spf13_bundle_groups, 'writing')
"            augroup textobj_quote
"                autocmd!
"                autocmd FileType markdown call textobj#quote#init()
"                autocmd FileType textile call textobj#quote#init()
"                autocmd FileType text call textobj#quote#init({'educate': 0})
"            augroup END
"        endif
"    " }

"    " PIV {
"        if isdirectory(expand("~/.config/nvim/plugged/PIV"))
"            let g:DisableAutoPHPFolding = 0
"            let g:PIVAutoClose = 0
"        endif
"    " }

"    " Misc {
"        if isdirectory(expand("~/.config/nvim/plugged/nerdtree"))
"            let g:NERDShutUp=1
"        endif
"        if isdirectory(expand("~/.config/nvim/plugged/matchit.zip"))
"            let b:match_ignorecase = 1
"        endif
"    " }

"    " OmniComplete {
"        " To disable omni complete, add the following to your .vimrc.before.local file:
"        "   let g:spf13_no_omni_complete = 1
"        if !exists('g:spf13_no_omni_complete')
"            if has("autocmd") && exists("+omnifunc")
"                autocmd Filetype *
"                    \if &omnifunc == "" |
"                    \setlocal omnifunc=syntaxcomplete#Complete |
"                    \endif
"            endif

"            hi Pmenu  guifg=#000000 guibg=#F8F8F8 ctermfg=black ctermbg=Lightgray
"            hi PmenuSbar  guifg=#8A95A7 guibg=#F8F8F8 gui=NONE ctermfg=darkcyan ctermbg=lightgray cterm=NONE
"            hi PmenuThumb  guifg=#F8F8F8 guibg=#8A95A7 gui=NONE ctermfg=lightgray ctermbg=darkcyan cterm=NONE

"            " Some convenient mappings
"            "inoremap <expr> <Esc>      pumvisible() ? "\<C-e>" : "\<Esc>"
"            if exists('g:spf13_map_cr_omni_complete')
"                inoremap <expr> <CR>     pumvisible() ? "\<C-y>" : "\<CR>"
"            endif
"            inoremap <expr> <Down>     pumvisible() ? "\<C-n>" : "\<Down>"
"            inoremap <expr> <Up>       pumvisible() ? "\<C-p>" : "\<Up>"
"            inoremap <expr> <C-d>      pumvisible() ? "\<PageDown>\<C-p>\<C-n>" : "\<C-d>"
"            inoremap <expr> <C-u>      pumvisible() ? "\<PageUp>\<C-p>\<C-n>" : "\<C-u>"

"            " Automatically open and close the popup menu / preview window
"            au CursorMovedI,InsertLeave * if pumvisible() == 0|silent! pclose|endif
"            set completeopt=menu,preview,longest
"        endif
"    " }

"    " Ctags {
"        set tags=./tags;/,~/.vimtags

"        " Make tags placed in .git/tags file available in all levels of a repository
"        let gitroot = substitute(system('git rev-parse --show-toplevel'), '[\n\r]', '', 'g')
"        if gitroot != ''
"            let &tags = &tags . ',' . gitroot . '/.git/tags'
"        endif
"    " }

"    " AutoCloseTag {
"        " Make it so AutoCloseTag works for xml and xhtml files as well
"        au FileType xhtml,xml ru ftplugin/html/autoclosetag.vim
"        nmap <Leader>ac <Plug>ToggleAutoCloseMappings
"    " }

"    " SnipMate {
"        " Setting the author var
"        " If forking, please overwrite in your .vimrc.local file
"        let g:snips_author = 'Steve Francia <steve.francia@gmail.com>'
"    " }

"    " NerdTree {
"        if isdirectory(expand("~/.config/nvim/plugged/nerdtree"))
"            map <C-e> <plug>NERDTreeTabsToggle<CR>
"            map <leader>e :NERDTreeFind<CR>
"            nmap <leader>nt :NERDTreeFind<CR>

"            let NERDTreeShowBookmarks=1
"            let NERDTreeIgnore=['\.py[cd]$', '\~$', '\.swo$', '\.swp$', '^\.git$', '^\.hg$', '^\.svn$', '\.bzr$']
"            let NERDTreeChDirMode=0
"            let NERDTreeQuitOnOpen=1
"            let NERDTreeMouseMode=2
"            let NERDTreeShowHidden=1
"            let NERDTreeKeepTreeInNewTab=1
"            let g:nerdtree_tabs_open_on_gui_startup=0
"        endif
"    " }

"    " Tabularize {
"        if isdirectory(expand("~/.config/nvim/plugged/tabular"))
"            nmap <Leader>a& :Tabularize /&<CR>
"            vmap <Leader>a& :Tabularize /&<CR>
"            nmap <Leader>a= :Tabularize /^[^=]*\zs=<CR>
"            vmap <Leader>a= :Tabularize /^[^=]*\zs=<CR>
"            nmap <Leader>a=> :Tabularize /=><CR>
"            vmap <Leader>a=> :Tabularize /=><CR>
"            nmap <Leader>a: :Tabularize /:<CR>
"            vmap <Leader>a: :Tabularize /:<CR>
"            nmap <Leader>a:: :Tabularize /:\zs<CR>
"            vmap <Leader>a:: :Tabularize /:\zs<CR>
"            nmap <Leader>a, :Tabularize /,<CR>
"            vmap <Leader>a, :Tabularize /,<CR>
"            nmap <Leader>a,, :Tabularize /,\zs<CR>
"            vmap <Leader>a,, :Tabularize /,\zs<CR>
"            nmap <Leader>a<Bar> :Tabularize /<Bar><CR>
"            vmap <Leader>a<Bar> :Tabularize /<Bar><CR>
"        endif
"    " }

"    " Session List {
"        set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize
"        if isdirectory(expand("~/.config/nvim/plugged/sessionman.vim/"))
"            nmap <leader>sl :SessionList<CR>
"            nmap <leader>ss :SessionSave<CR>
"            nmap <leader>sc :SessionClose<CR>
"        endif
"    " }

"    " JSON {
"        nmap <leader>jt <Esc>:%!python -m json.tool<CR><Esc>:set filetype=json<CR>
"        let g:vim_json_syntax_conceal = 0
"    " }

"    " PyMode {
"        " Disable if python support not present
"        if !has('python') && !has('python3')
"            let g:pymode = 0
"        endif

"        if isdirectory(expand("~/.config/nvim/plugged/python-mode"))
"            let g:pymode_lint_checkers = ['pyflakes']
"            let g:pymode_trim_whitespaces = 0
"            let g:pymode_options = 0
"            let g:pymode_rope = 0
"        endif
"    " }

"    " ctrlp {
"        if isdirectory(expand("~/.config/nvim/plugged/ctrlp.vim/"))
"            let g:ctrlp_working_path_mode = 'ra'
"            nnoremap <silent> <D-t> :CtrlP<CR>
"            nnoremap <silent> <D-r> :CtrlPMRU<CR>
"            let g:ctrlp_custom_ignore = {
"                \ 'dir':  '\.git$\|\.hg$\|\.svn$',
"                \ 'file': '\.exe$\|\.so$\|\.dll$\|\.pyc$' }

"            if executable('ag')
"                let s:ctrlp_fallback = 'ag %s --nocolor -l -g ""'
"            elseif executable('ack-grep')
"                let s:ctrlp_fallback = 'ack-grep %s --nocolor -f'
"            elseif executable('ack')
"                let s:ctrlp_fallback = 'ack %s --nocolor -f'
"            " On Windows use "dir" as fallback command.
"            elseif WINDOWS()
"                let s:ctrlp_fallback = 'dir %s /-n /b /s /a-d'
"            else
"                let s:ctrlp_fallback = 'find %s -type f'
"            endif
"            if exists("g:ctrlp_user_command")
"                unlet g:ctrlp_user_command
"            endif
"            let g:ctrlp_user_command = {
"                \ 'types': {
"                    \ 1: ['.git', 'cd %s && git ls-files . --cached --exclude-standard --others'],
"                    \ 2: ['.hg', 'hg --cwd %s locate -I .'],
"                \ },
"                \ 'fallback': s:ctrlp_fallback
"            \ }

"            if isdirectory(expand("~/.config/nvim/plugged/ctrlp-funky/"))
"                " CtrlP extensions
"                let g:ctrlp_extensions = ['funky']

"                "funky
"                nnoremap <Leader>fu :CtrlPFunky<Cr>
"            endif
"        endif
"    "}

"    " TagBar {
"        if isdirectory(expand("~/.config/nvim/plugged/tagbar/"))
"            nnoremap <silent> <leader>tt :TagbarToggle<CR>
"        endif
"    "}

"    " Rainbow {
"        if isdirectory(expand("~/.config/nvim/plugged/rainbow/"))
"            let g:rainbow_active = 1 "0 if you want to enable it later via :RainbowToggle
"        endif
"    "}

"    " Fugitive {
"        if isdirectory(expand("~/.config/nvim/plugged/vim-fugitive/"))
"            nnoremap <silent> <leader>gs :Gstatus<CR>
"            nnoremap <silent> <leader>gd :Gdiff<CR>
"            nnoremap <silent> <leader>gc :Gcommit<CR>
"            nnoremap <silent> <leader>gb :Gblame<CR>
"            nnoremap <silent> <leader>gl :Glog<CR>
"            nnoremap <silent> <leader>gp :Git push<CR>
"            nnoremap <silent> <leader>gr :Gread<CR>
"            nnoremap <silent> <leader>gw :Gwrite<CR>
"            nnoremap <silent> <leader>ge :Gedit<CR>
"            " Mnemonic _i_nteractive
"            nnoremap <silent> <leader>gi :Git add -p %<CR>
"            nnoremap <silent> <leader>gg :SignifyToggle<CR>
"        endif
"    "}

"    " YouCompleteMe {
"        if count(g:spf13_bundle_groups, 'youcompleteme')
"            let g:acp_enableAtStartup = 0

"            " enable completion from tags
"            let g:ycm_collect_identifiers_from_tags_files = 1

"            " remap Ultisnips for compatibility for YCM
"            let g:UltiSnipsExpandTrigger = '<C-j>'
"            let g:UltiSnipsJumpForwardTrigger = '<C-j>'
"            let g:UltiSnipsJumpBackwardTrigger = '<C-k>'

"            " Enable omni completion.
"            autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
"            autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
"            autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
"            autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
"            autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
"            autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
"            autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

"            " Haskell post write lint and check with ghcmod
"            " $ `cabal install ghcmod` if missing and ensure
"            " ~/.cabal/bin is in your $PATH.
"            if !executable("ghcmod")
"                autocmd BufWritePost *.hs GhcModCheckAndLintAsync
"            endif

"            " For snippet_complete marker.
"            if !exists("g:spf13_no_conceal")
"                if has('conceal')
"                    set conceallevel=2 concealcursor=i
"                endif
"            endif

"            " Disable the neosnippet preview candidate window
"            " When enabled, there can be too much visual noise
"            " especially when splits are used.
"            set completeopt-=preview
"        endif
"    " }

"    " neocomplete {
"        if count(g:spf13_bundle_groups, 'neocomplete')
"            let g:acp_enableAtStartup = 0
"            let g:neocomplete#enable_at_startup = 1
"            let g:neocomplete#enable_smart_case = 1
"            let g:neocomplete#enable_auto_delimiter = 1
"            let g:neocomplete#max_list = 15
"            let g:neocomplete#force_overwrite_completefunc = 1


"            " Define dictionary.
"            let g:neocomplete#sources#dictionary#dictionaries = {
"                        \ 'default' : '',
"                        \ 'vimshell' : $HOME.'/.vimshell_hist',
"                        \ 'scheme' : $HOME.'/.gosh_completions'
"                        \ }

"            " Define keyword.
"            if !exists('g:neocomplete#keyword_patterns')
"                let g:neocomplete#keyword_patterns = {}
"            endif
"            let g:neocomplete#keyword_patterns['default'] = '\h\w*'

"            " Plugin key-mappings {
"                " These two lines conflict with the default digraph mapping of <C-K>
"                if !exists('g:spf13_no_neosnippet_expand')
"                    imap <C-k> <Plug>(neosnippet_expand_or_jump)
"                    smap <C-k> <Plug>(neosnippet_expand_or_jump)
"                endif
"                if exists('g:spf13_noninvasive_completion')
"                    inoremap <CR> <CR>
"                    " <ESC> takes you out of insert mode
"                    inoremap <expr> <Esc>   pumvisible() ? "\<C-y>\<Esc>" : "\<Esc>"
"                    " <CR> accepts first, then sends the <CR>
"                    inoremap <expr> <CR>    pumvisible() ? "\<C-y>\<CR>" : "\<CR>"
"                    " <Down> and <Up> cycle like <Tab> and <S-Tab>
"                    inoremap <expr> <Down>  pumvisible() ? "\<C-n>" : "\<Down>"
"                    inoremap <expr> <Up>    pumvisible() ? "\<C-p>" : "\<Up>"
"                    " Jump up and down the list
"                    inoremap <expr> <C-d>   pumvisible() ? "\<PageDown>\<C-p>\<C-n>" : "\<C-d>"
"                    inoremap <expr> <C-u>   pumvisible() ? "\<PageUp>\<C-p>\<C-n>" : "\<C-u>"
"                else
"                    " <C-k> Complete Snippet
"                    " <C-k> Jump to next snippet point
"                    imap <silent><expr><C-k> neosnippet#expandable() ?
"                                \ "\<Plug>(neosnippet_expand_or_jump)" : (pumvisible() ?
"                                \ "\<C-e>" : "\<Plug>(neosnippet_expand_or_jump)")
"                    smap <TAB> <Right><Plug>(neosnippet_jump_or_expand)

"                    inoremap <expr><C-g> neocomplete#undo_completion()
"                    inoremap <expr><C-l> neocomplete#complete_common_string()
"                    "inoremap <expr><CR> neocomplete#complete_common_string()

"                    " <CR>: close popup
"                    " <s-CR>: close popup and save indent.
"                    inoremap <expr><s-CR> pumvisible() ? neocomplete#smart_close_popup()."\<CR>" : "\<CR>"

"                    function! CleverCr()
"                        if pumvisible()
"                            if neosnippet#expandable()
"                                let exp = "\<Plug>(neosnippet_expand)"
"                                return exp . neocomplete#smart_close_popup()
"                            else
"                                return neocomplete#smart_close_popup()
"                            endif
"                        else
"                            return "\<CR>"
"                        endif
"                    endfunction

"                    " <CR> close popup and save indent or expand snippet
"                    imap <expr> <CR> CleverCr()
"                    " <C-h>, <BS>: close popup and delete backword char.
"                    inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
"                    inoremap <expr><C-y> neocomplete#smart_close_popup()
"                endif
"                " <TAB>: completion.
"                inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
"                inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<TAB>"

"                " Courtesy of Matteo Cavalleri

"                function! CleverTab()
"                    if pumvisible()
"                        return "\<C-n>"
"                    endif
"                    let substr = strpart(getline('.'), 0, col('.') - 1)
"                    let substr = matchstr(substr, '[^ \t]*$')
"                    if strlen(substr) == 0
"                        " nothing to match on empty string
"                        return "\<Tab>"
"                    else
"                        " existing text matching
"                        if neosnippet#expandable_or_jumpable()
"                            return "\<Plug>(neosnippet_expand_or_jump)"
"                        else
"                            return neocomplete#start_manual_complete()
"                        endif
"                    endif
"                endfunction

"                imap <expr> <Tab> CleverTab()
"            " }

"            " Enable heavy omni completion.
"            if !exists('g:neocomplete#sources#omni#input_patterns')
"                let g:neocomplete#sources#omni#input_patterns = {}
"            endif
"            let g:neocomplete#sources#omni#input_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
"            let g:neocomplete#sources#omni#input_patterns.perl = '\h\w*->\h\w*\|\h\w*::'
"            let g:neocomplete#sources#omni#input_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
"            let g:neocomplete#sources#omni#input_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'
"            let g:neocomplete#sources#omni#input_patterns.ruby = '[^. *\t]\.\h\w*\|\h\w*::'
"    " }
"    " neocomplcache {
"        elseif count(g:spf13_bundle_groups, 'neocomplcache')
"            let g:acp_enableAtStartup = 0
"            let g:neocomplcache_enable_at_startup = 1
"            let g:neocomplcache_enable_camel_case_completion = 1
"            let g:neocomplcache_enable_smart_case = 1
"            let g:neocomplcache_enable_underbar_completion = 1
"            let g:neocomplcache_enable_auto_delimiter = 1
"            let g:neocomplcache_max_list = 15
"            let g:neocomplcache_force_overwrite_completefunc = 1

"            " Define dictionary.
"            let g:neocomplcache_dictionary_filetype_lists = {
"                        \ 'default' : '',
"                        \ 'vimshell' : $HOME.'/.vimshell_hist',
"                        \ 'scheme' : $HOME.'/.gosh_completions'
"                        \ }

"            " Define keyword.
"            if !exists('g:neocomplcache_keyword_patterns')
"                let g:neocomplcache_keyword_patterns = {}
"            endif
"            let g:neocomplcache_keyword_patterns._ = '\h\w*'

"            " Plugin key-mappings {
"                " These two lines conflict with the default digraph mapping of <C-K>
"                imap <C-k> <Plug>(neosnippet_expand_or_jump)
"                smap <C-k> <Plug>(neosnippet_expand_or_jump)
"                if exists('g:spf13_noninvasive_completion')
"                    inoremap <CR> <CR>
"                    " <ESC> takes you out of insert mode
"                    inoremap <expr> <Esc>   pumvisible() ? "\<C-y>\<Esc>" : "\<Esc>"
"                    " <CR> accepts first, then sends the <CR>
"                    inoremap <expr> <CR>    pumvisible() ? "\<C-y>\<CR>" : "\<CR>"
"                    " <Down> and <Up> cycle like <Tab> and <S-Tab>
"                    inoremap <expr> <Down>  pumvisible() ? "\<C-n>" : "\<Down>"
"                    inoremap <expr> <Up>    pumvisible() ? "\<C-p>" : "\<Up>"
"                    " Jump up and down the list
"                    inoremap <expr> <C-d>   pumvisible() ? "\<PageDown>\<C-p>\<C-n>" : "\<C-d>"
"                    inoremap <expr> <C-u>   pumvisible() ? "\<PageUp>\<C-p>\<C-n>" : "\<C-u>"
"                else
"                    imap <silent><expr><C-k> neosnippet#expandable() ?
"                                \ "\<Plug>(neosnippet_expand_or_jump)" : (pumvisible() ?
"                                \ "\<C-e>" : "\<Plug>(neosnippet_expand_or_jump)")
"                    smap <TAB> <Right><Plug>(neosnippet_jump_or_expand)

"                    inoremap <expr><C-g> neocomplcache#undo_completion()
"                    inoremap <expr><C-l> neocomplcache#complete_common_string()
"                    "inoremap <expr><CR> neocomplcache#complete_common_string()

"                    function! CleverCr()
"                        if pumvisible()
"                            if neosnippet#expandable()
"                                let exp = "\<Plug>(neosnippet_expand)"
"                                return exp . neocomplcache#close_popup()
"                            else
"                                return neocomplcache#close_popup()
"                            endif
"                        else
"                            return "\<CR>"
"                        endif
"                    endfunction

"                    " <CR> close popup and save indent or expand snippet
"                    imap <expr> <CR> CleverCr()

"                    " <CR>: close popup
"                    " <s-CR>: close popup and save indent.
"                    inoremap <expr><s-CR> pumvisible() ? neocomplcache#close_popup()."\<CR>" : "\<CR>"
"                    "inoremap <expr><CR> pumvisible() ? neocomplcache#close_popup() : "\<CR>"

"                    " <C-h>, <BS>: close popup and delete backword char.
"                    inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
"                    inoremap <expr><C-y> neocomplcache#close_popup()
"                endif
"                " <TAB>: completion.
"                inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
"                inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<TAB>"
"            " }

"            " Enable omni completion.
"            autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
"            autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
"            autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
"            autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
"            autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
"            autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
"            autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

"            " Enable heavy omni completion.
"            if !exists('g:neocomplcache_omni_patterns')
"                let g:neocomplcache_omni_patterns = {}
"            endif
"            let g:neocomplcache_omni_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
"            let g:neocomplcache_omni_patterns.perl = '\h\w*->\h\w*\|\h\w*::'
"            let g:neocomplcache_omni_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
"            let g:neocomplcache_omni_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'
"            let g:neocomplcache_omni_patterns.ruby = '[^. *\t]\.\h\w*\|\h\w*::'
"            let g:neocomplcache_omni_patterns.go = '\h\w*\.\?'
"    " }
"    " Normal Vim omni-completion {
"    " To disable omni complete, add the following to your .vimrc.before.local file:
"    "   let g:spf13_no_omni_complete = 1
"        elseif !exists('g:spf13_no_omni_complete')
"            " Enable omni-completion.
"            autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
"            autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
"            autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
"            autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
"            autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
"            autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
"            autocmd FileType haskell setlocal omnifunc=necoghc#omnifunc

"        endif
"    " }

"    " Snippets {
"        if count(g:spf13_bundle_groups, 'neocomplcache') ||
"                    \ count(g:spf13_bundle_groups, 'neocomplete')

"            " Use honza's snippets.
"            let g:neosnippet#snippets_directory='~/.config/nvim/plugged/vim-snippets/snippets'

"            " Enable neosnippet snipmate compatibility mode
"            let g:neosnippet#enable_snipmate_compatibility = 1

"            " For snippet_complete marker.
"            if !exists("g:spf13_no_conceal")
"                if has('conceal')
"                    set conceallevel=2 concealcursor=i
"                endif
"            endif

"            " Enable neosnippets when using go
"            let g:go_snippet_engine = "neosnippet"

"            " Disable the neosnippet preview candidate window
"            " When enabled, there can be too much visual noise
"            " especially when splits are used.
"            set completeopt-=preview
"        endif
"    " }

"    " FIXME: Isn't this for Syntastic to handle?
"    " Haskell post write lint and check with ghcmod
"    " $ `cabal install ghcmod` if missing and ensure
"    " ~/.cabal/bin is in your $PATH.
"    if !executable("ghcmod")
"        autocmd BufWritePost *.hs GhcModCheckAndLintAsync
"    endif

"    " UndoTree {
"        if isdirectory(expand("~/.config/nvim/plugged/undotree/"))
"            nnoremap <Leader>u :UndotreeToggle<CR>
"            " If undotree is opened, it is likely one wants to interact with it.
"            let g:undotree_SetFocusWhenToggle=1
"        endif
"    " }

"    " indent_guides {
"        if isdirectory(expand("~/.config/nvim/plugged/vim-indent-guides/"))
"            let g:indent_guides_start_level = 2
"            let g:indent_guides_guide_size = 1
"            let g:indent_guides_enable_on_vim_startup = 1
"        endif
"    " }

"    " Wildfire {
"    let g:wildfire_objects = {
"                \ "*" : ["i'", 'i"', "i)", "i]", "i}", "ip"],
"                \ "html,xml" : ["at"],
"                \ }

"    " vim-airline {
"        " Set configuration options for the statusline plugin vim-airline.
"        " Use the powerline theme and optionally enable powerline symbols.
"        " To use the symbols , , , , , , and .in the statusline
"        " segments add the following to your .vimrc.before.local file:
"        "   let g:airline_powerline_fonts=1
"        " If the previous symbols do not render for you then install a
"        " powerline enabled font.

"        " See `:echo g:airline_theme_map` for some more choices
"        " Default in terminal vim is 'dark'
"        if isdirectory(expand("~/.config/nvim/plugged/vim-airline-themes/"))
"            if !exists('g:airline_theme')
"                let g:airline_theme = 'solarized'
"            endif
"            if !exists('g:airline_powerline_fonts')
"                " Use the default set of separators with a few customizations
"                let g:airline_left_sep='›'  " Slightly fancier than '>'
"                let g:airline_right_sep='‹' " Slightly fancier than '<'
"            endif
"        endif
"    " }



"" }

" --> About Solarized colors schemes switch
"  SwitchToggleSolarized {
" For more info type :help highlight
function! ToggleDarkSolarized()
  syntax on
  call ActivateRainbow()
  set background=dark
  highlight Normal            cterm=none ctermbg=none ctermfg=DarkGrey
  highlight LineNr            cterm=bold ctermbg=none ctermfg=DarkGrey
  highlight foldcolumn                   ctermbg=none ctermfg=none
  highlight CursorLine                   ctermbg=none
  highlight SignColumn        cterm=none ctermbg=none
  highlight SignifySignAdd    cterm=bold ctermbg=none ctermfg=64
  highlight SignifySignDelete cterm=none ctermbg=none ctermfg=136
  highlight SignifySignChange cterm=none ctermbg=none ctermfg=124
  highlight Folded                       ctermbg=none
endfunction

function! ToggleLightSolarized()
  syntax on
  call ActivateRainbow()
  set background=light
  highlight Normal            cterm=none ctermbg=230 ctermfg=DarkGrey
  highlight LineNr            cterm=bold
  highlight SignColumn        cterm=none ctermbg=187 ctermfg=240
  highlight SignifySignAdd    cterm=bold ctermbg=187 ctermfg=64
  highlight SignifySignDelete cterm=none ctermbg=187 ctermfg=136
  highlight SignifySignChange cterm=none ctermbg=187 ctermfg=124
endfunction

function! SwitchToggleSolarized()
  if &background == "light"
    call ToggleDarkSolarized()
  else
    call ToggleLightSolarized()
  endif
endfunction
" }

" { Before

" Rainbow plugin : (parenthesis and brackets colored by level)
"let g:rainbow_active = 1

" {Python pymode plugin :
"let g:pymode = 0
"let g:pymode_breakpoint = 0

let g:pymode_options_max_line_length = 79
let g:pymode_indent = 1 " pep8 indent
let g:pymode_folding = 1
let g:pymode_motion = 1

" doc
let g:pymode_doc = 1
let g:pymode_doc_bind = 'K'

" syntax
let g:pymode_syntax = 1
let g:pymode_syntax_all = 1
let g:pymode_syntax_slow_sync = 1 " slower syntax sync

" Disable leader+r to run script
let g:pymode_run = 0

" pymode syntax
let g:pymode_syntax = 1
"let g:pymode_syntax_builtin_objs = g:pymode_syntax_all
"let g:pymode_syntax_builtin_funcs = 1

" Python code checking :
let g:pymode_lint = 1
let g:pymode_lint_on_write = 1
let g:pymode_lint_checkers = ['pep8', 'pyflakes'] " pep8 code checker


let g:pymode_lint_signs = 1
let g:pymode_lint_cwindow = 0
let g:pymode_lint_message = 1

" Code completion :
"let g:pymode_rope = 1 " enable rope which is slow
"let g:pymode_rope_completion = 1 " enable completion
"let g:pymode_rope_lookup_project = 0 " do not lookup in parent directories which is slow
"let g:pymode_rope_autoimport = 0
"}

" {FastFold :
let g:python_fold=1
" To avoid z remapping and loosing nowait :
let g:fastfold_fold_movement_commands = []
let g:fastfold_fold_command_suffixes = []
" actualize folds when save :
let g:fastfold_savehook = 1
" }

"let g:deoplete#enable_at_startup = 1
"let g:deoplete#enable_refresh_always = 1 "Deoplete refreshes the candidates automatically
let g:jedi#completions_enabled = 0
let g:jedi#auto_vim_configuration = 0
let g:jedi#smart_auto_mappings = 0
let g:jedi#show_call_signatures = 0

" }

" { Some Mapping
" Buffers {
" Unmapping F1 calling help in vim :
map <F1> <nop>
map <A-F1> <nop>

" --> About buffers switch
" Little snippet to get all alt key mapping functional :
" works for alt-a .. alt-z
for i in range(97,122)
  let c = nr2char(i)
  exec "map \e".c." <M-".c.">"
  exec "map! \e".c." <M-".c.">"
endfor

"" fix meta-keys which generate <Esc>a .. <Esc>z
"let c='a'
"while c <= 'z'
"  exec "set <M-".toupper(c).">=\e".c
"  exec "imap \e".c." <M-".toupper(c).">"
"  let c = nr2char(1+char2nr(c))
"endw

if has('nvim')
  "set ttimeoutlen=-1
  "map <nowait> <A-a> :bp<cr>>
  "map <nowait> <A-z> :bn<cr>
  "map <nowait> <A-e> :cn<cr>
else
  " Mapping with alt-Fx
  " https://stackoverflow.com/questions/7501092/can-i-map-alt-key-in-vim
  " ALT + F1 :
  exec "set <S-F1>=\eO1;3P"
  " ALT + F2 :
  exec "set <S-F2>=\eO1;3Q"
  " ALT + F3 :
  exec "set <S-F3>=\eO1;3R"
  map <nowait> <S-F1> :bp<cr>
  map <nowait> <S-F2> :bn<cr>
  " Open next occurence of search (git jump grep "something") :
  map <nowait> <S-F3> :cn<cr>
endif

" buffer delete without closing windows :
nmap <silent> <leader>bd :bp\|bd #<CR>
"}

"" parenthesis/brackets/etc ...{
vnoremap <Leader>( <esc>`>a)<esc>`<i(<esc>
vnoremap <Leader>) <esc>`>a)<esc>`<i(<esc>
vnoremap <Leader>[ <esc>`>a]<esc>`<i[<esc>
vnoremap <Leader>] <esc>`>a]<esc>`<i[<esc>
vnoremap <Leader>{ <esc>`>a}<esc>`<i{<esc>
vnoremap <Leader>} <esc>`>a}<esc>`<i{<esc>
vnoremap <Leader>" <esc>`>a"<esc>`<i"<esc>
vnoremap <Leader>' <esc>`>a'<esc>`<i'<esc>
vnoremap <Leader>` <esc>`>a`<esc>`<i`<esc>
"" }

" Movements binds : {

" Folding binds : {
" --> About folding open and close :
nnoremap <Space> za
vnoremap <Space> za

" --> Folding : closing all opened foldings :
nnoremap wm zm
vnoremap wm zm

" --> Folding : movements (next / prec) :
nnoremap wj zj
vnoremap wj zj
nnoremap wk zk
vnoremap wk zk
" }

" qwerty --> azerty beginning of the next word eased by this bind :
" the <nowait> prevent a delay when typing z (for za for example)
noremap <nowait> z w
noremap <nowait> Z b
noremap <nowait> e e
noremap <nowait> E ge

" EasyMotion :
" Gif config
map  <leader>/ <Plug>(easymotion-sn)
omap <leader>/ <Plug>(easymotion-tn)
map <nowait><Leader>l <Plug>(easymotion-lineforward)
map <nowait><Leader>j <Plug>(easymotion-j)
map <nowait><Leader>k <Plug>(easymotion-k)
map <nowait><Leader>h <Plug>(easymotion-linebackward)

" <Leader>f{char} to move to {char}
map  <nowait><Leader>f <Plug>(easymotion-bd-f)
nmap <nowait><Leader>f <Plug>(easymotion-overwin-f)

" beginning of words :
map <nowait><leader>z <Plug>(easymotion-w)
map <nowait><leader>Z <Plug>(easymotion-b)

" end of words :
map <nowait><leader>e <Plug>(easymotion-e)
map <nowait><leader>E <Plug>(easymotion-ge)

" jump to anywhere :
map <nowait><leader><leader> <Plug>(easymotion-jumptoanywhere)

" About jump to beginning of word :
"map <S-e> b

" --> About moving splits :
map <a-h> <C-W>h
map <a-j> <C-W>j
map <a-k> <C-W>k
map <a-l> <C-W>l

" }

" nowait bindinds : {
nmap <nowait> O O
" }

" copy to clipboard :
vnoremap <Leader>y "+y

" -->  Bind nohl : Removes highlight of your last search
" ``<C>`` stands for ``CTRL`` and therefore ``<C-n>`` stands for ``CTRL+n``
map  <nowait> <Leader>; :nohl<CR>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>
" Avoid qq recording
nnoremap q <Nop>

map <F12> :source ${HOME}/.config/nvim/init.vim<cr>

set timeoutlen=1000 ttimeoutlen=10

" Settings for python-mode
"map <Leader>b oimport ipdb; ipdb.set_trace() # BREAKPOINT<C-c>
map <Leader>i ofrom IPython import embed; embed() # Enter Ipython<C-c>

" Settings for ctrlp
let g:ctrlp_max_height = 30
set wildignore+=*.pyc
set wildignore+=*_build/*
set wildignore+=*/coverage/*

" --> Changing theme :
" ALT + F3 :
"map O1;3R :call SwitchToggleSolarized()<cr>

" --> Mapping function call:
map <F8> :call SwitchToggleAutoIndent()<cr>

"  alt + ²
map <Esc>² :call ExecAndBuild() <cr>
"}

" { Some Global config

" neosnippet config :
let g:snips_author = 'Guillaume Jeusel <guillaume.jeusel@gmail.com>'

" leave insert mode quickly
if !has('gui_running')
  set ttimeoutlen=10
  augroup FastEscape
    autocmd!
    au InsertEnter * set timeoutlen=0
    au InsertLeave * set timeoutlen=1000
  augroup END
endif
map <nowait> <Esc> <C-c>
" quick escape from command line with esc :
cmap <nowait> <Esc> <C-c>

" --> About Colors & Themes defaults : {
set t_Co=256            " use 256 colors in vim
"colorscheme solarized   " an appropriate color scheme

"" --> Cursor color
"if &term =~ "xterm\\|rxvt"
"  " use an orange cursor in insert mode
"  let &t_SI = "\<Esc>]12;orange\x7"
"  " use a DarkGrey cursor otherwise
"  let &t_EI = "\<Esc>]12;DarkGrey\x7"
"  silent !echo -ne "\033]12;DarkGrey\007"
"  " reset cursor when vim exits
"  autocmd VimLeave * silent !echo -ne "\033]112\007"
"  " use \003]12;gray\007 for gnome-terminal
"endif
""}

" --> Cleapboard access :
set clipboard+=unnamedplus

" --> Regarding folds :
set foldmethod=marker
set foldtext=MyFoldText()
function! MyFoldText()
  let line = getline(v:foldstart)
  let sub = substitute(line, '/\*\|\*/\|{\d\=', '', 'g')
  "}
  return v:folddashes . sub
endfunction
set foldcolumn=2
"setlocal foldnestmax=1

" --> Filetype defaults :
if has("autocmd")
  au BufNewFile,BufRead *.cuf set filetype=fortran
  au BufNewFile,BufRead *.nml set filetype=fortran
  au BufNewFile,BufRead *.namelist set filetype=fortran
  au BufNewFile,BufRead *.nix set filetype=nix
  au BufNewFile,BufRead *.sh set filetype=sh
  au BufNewFile,BufRead *.vimrc* set filetype=vim
  au BufNewFile,BufRead *.vim set filetype=vim
  au BufNewFile,BufRead *.cmake set filetype=cmake
  au BufNewFile,BufRead CMakeLists.txt set filetype=cmake
endif

"}
