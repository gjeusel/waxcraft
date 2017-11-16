" vim: set sw=4 ts=4 sts=4 et tw=78 foldmarker={,} foldlevel=0 foldmethod=marker spell:

"set runtimepath+=~/.vim,~/.vim/after
"set packpath+=~/.vim
"source ~/.vimrc

" Bundles {

" Setup Bundle Support {
" The next three lines ensure that the ~/.vim/bundle/ system works
filetype off
set rtp+=~/.vim/bundle/vundle
call vundle#rc()
" }

" General {
Bundle 'altercation/vim-colors-solarized'
Bundle 'spf13/vim-colors'
Bundle 'tpope/vim-surround'
Bundle 'tpope/vim-repeat'
Bundle 'rhysd/conflict-marker.vim'
"Bundle 'jiangmiao/auto-pairs'
Bundle 'ctrlpvim/ctrlp.vim'
Bundle 'tacahiroy/ctrlp-funky'
Bundle 'terryma/vim-multiple-cursors'
Bundle 'vim-scripts/sessionman.vim'
Bundle 'matchit.zip'
Bundle 'Lokaltog/vim-powerline'
Bundle 'powerline/fonts'
Bundle 'bling/vim-bufferline'
Bundle 'easymotion/vim-easymotion'
Bundle 'flazz/vim-colorschemes'
Bundle 'mbbill/undotree'
Bundle 'nathanaelkane/vim-indent-guides'
Bundle 'vim-scripts/restore_view.vim'
Bundle 'mhinz/vim-signify'
Bundle 'tpope/vim-abolish.git'
Bundle 'osyo-manga/vim-over'
Bundle 'kana/vim-textobj-user'
Bundle 'kana/vim-textobj-indent'
Bundle 'gcmt/wildfire.vim'
"}

" General Programming {
    " Pick one of the checksyntax, jslint, or syntastic
    Bundle 'scrooloose/syntastic'
    Bundle 'tpope/vim-fugitive'
    Bundle 'mattn/webapi-vim'
    Bundle 'mattn/gist-vim'
    Bundle 'scrooloose/nerdcommenter'
    Bundle 'tpope/vim-commentary'
    Bundle 'godlygeek/tabular'
    Bundle 'luochen1990/rainbow'
    if executable('ctags')
        Bundle 'majutsushi/tagbar'
    endif
" }

Bundle TFenby/python-mode', { 'branch' : 'develop' }
Bundle LnL7/vim-nix'
Bundle octol/vim-cpp-enhanced-highlight'
Bundle Konfekt/FastFold'
Bundle Konfekt/FoldText'
Bundle SirVer/ultisnips'

" Snippets & AutoComplete {
Bundle 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Bundle 'zchee/deoplete-jedi'
Bundle 'zchee/deoplete-go'
" }

"}

" Plugin config {

" Tabularize {
if isdirectory(expand("~/.vim/bundle/tabular"))
    nmap <Leader>a& :Tabularize /&<CR>
    vmap <Leader>a& :Tabularize /&<CR>
    nmap <Leader>a= :Tabularize /^[^=]*\zs=<CR>
    vmap <Leader>a= :Tabularize /^[^=]*\zs=<CR>
    nmap <Leader>a=> :Tabularize /=><CR>
    vmap <Leader>a=> :Tabularize /=><CR>
    nmap <Leader>a: :Tabularize /:<CR>
    vmap <Leader>a: :Tabularize /:<CR>
    nmap <Leader>a:: :Tabularize /:\zs<CR>
    vmap <Leader>a:: :Tabularize /:\zs<CR>
    nmap <Leader>a, :Tabularize /,<CR>
    vmap <Leader>a, :Tabularize /,<CR>
    nmap <Leader>a,, :Tabularize /,\zs<CR>
    vmap <Leader>a,, :Tabularize /,\zs<CR>
    nmap <Leader>a<Bar> :Tabularize /<Bar><CR>
    vmap <Leader>a<Bar> :Tabularize /<Bar><CR>
endif
"}

" Session List {
set sessionoptions=blank,buffers,curdir,folds,tabpages,winsize
if isdirectory(expand("~/.vim/bundle/sessionman.vim/"))
    nmap <leader>sl :SessionList<CR>
    nmap <leader>ss :SessionSave<CR>
    nmap <leader>sc :SessionClose<CR>
endif
" }

" PyMode {
" Disable if python support not present
if !has('python') && !has('python3')
    let g:pymode = 0
endif

if isdirectory(expand("~/.vim/bundle/python-mode"))
    let g:pymode_lint_checkers = ['pyflakes']
    let g:pymode_trim_whitespaces = 0
    let g:pymode_options = 0
    let g:pymode_rope = 0
endif
" }

" vim-airline {
" Set configuration options for the statusline plugin vim-airline.
" Use the powerline theme and optionally enable powerline symbols.
" To use the symbols , , , , , , and .in the statusline
" segments add the following to your .vimrc.before.local file:
"   let g:airline_powerline_fonts=1
" If the previous symbols do not render for you then install a
" powerline enabled font.

" See `:echo g:airline_theme_map` for some more choices
" Default in terminal vim is 'dark'
if isdirectory(expand("~/.vim/bundle/vim-airline-themes/"))
    if !exists('g:airline_theme')
        let g:airline_theme = 'solarized'
    endif
    if !exists('g:airline_powerline_fonts')
        " Use the default set of separators with a few customizations
        let g:airline_left_sep='›'  " Slightly fancier than '>'
        let g:airline_right_sep='‹' " Slightly fancier than '<'
    endif
endif
" }

" }

" Before {

let g:snips_author = 'Guillaume Jeusel <guillaume.jeusel@gmail.com>'

" Appearence {
if filereadable(expand("~/.vim/bundle/vim-colors-solarized/colors/solarized.vim"))
    let g:solarized_termcolors=256
    let g:solarized_termtrans=1
    let g:solarized_contrast="normal"
    let g:solarized_visibility="normal"
    color solarized             " Load a colorscheme
endif
"}

if isdirectory(expand("~/.vim/bundle/rainbow/"))
    let g:rainbow_active = 1 "0 if you want to enable it later via :RainbowToggle
endif

"}

" After {

" General {

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
" a new buffer is opened:
autocmd BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif

set virtualedit=onemore             " Allow for cursor beyond last character
set history=1000                    " Store a ton of history (default is 20)
set spell                           " Spell checking on
set hidden                          " Allow buffer switching without saving

" Instead of reverting the cursor to the last position in the buffer, we
" set it to the first line when editing a git commit message
au FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])

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
"}

" Setting up the directories {
set backup                  " Backups are nice ...
if has('persistent_undo')
    set undofile                " So is persistent undo ...
    set undolevels=1000         " Maximum number of changes that can be undone
    set undoreload=10000        " Maximum number lines to save for undo on a buffer reload
endif

" Add exclusions to mkview and loadview
" eg: *.*, svn-commit.tmp
let g:skipview_files = [
            \ '\[example pattern\]'
            \ ]
" }

" User Interface {
highlight clear SignColumn      " SignColumn should match background
highlight clear LineNr          " Current line number row will have same background color in relative mode

set backspace=indent,eol,start  " Backspace for dummies
set number                      " Line numbers on
set showmatch                   " Show matching brackets/parenthesis
set incsearch                   " Find as you type search
set hlsearch                    " Highlight search terms
set ignorecase                  " Case insensitive search
set smartcase                   " Case sensitive when uc present
set scrolljump=5                " Lines to scroll when cursor leaves screen
set scrolloff=3                 " Minimum lines to keep above and below cursor
set foldenable                  " Auto fold code
set foldcolumn=2
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
set matchpairs+=<:>             " Match, to be used with %

"set comments=sl:/*,mb:*,elx:*/  " auto format comment blocks
" Remove trailing whitespaces and ^M chars
autocmd FileType c,cpp,java,go,php,javascript,puppet,python,rust,twig,xml,yml,perl,sql autocmd BufWritePre <buffer> if !exists('g:spf13_keep_trailing_whitespace') | call StripTrailingWhitespace() | endif
" }

"}

" Key (re)Mappings {:
let mapleader = ','

" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null

" Map <Leader>ff to display all lines with keyword under cursor
" and ask which one to jump to
nmap <Leader>ff [I:let nr = input("Which one: ")<Bar>exe "normal " . nr ."[\t"<CR>

map <leader>p :call ToggleProfiling()<cr>
map <F8> :call SwitchToggleAutoIndent()<cr>
map <F12> :source ${HOME}/.config/nvim/init.vim<cr>

" Buffers mapping {
" Little snippet to get all alt key mapping functional :
" works for alt-a .. alt-z
for i in range(97,122)
    let c = nr2char(i)
    exec "map \e".c." <M-".c.">"
    exec "map! \e".c." <M-".c.">"
endfor

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

" buffer delete without closing windows :
nmap <silent> <leader>bd :bp\|bd #<CR>
"}

" wrap with parenthesis/brackets/etc {
vnoremap <Leader>( <esc>`>a)<esc>`<i(<esc>
vnoremap <Leader>) <esc>`>a)<esc>`<i(<esc>
vnoremap <Leader>[ <esc>`>a]<esc>`<i[<esc>
vnoremap <Leader>] <esc>`>a]<esc>`<i[<esc>
vnoremap <Leader>{ <esc>`>a}<esc>`<i{<esc>
vnoremap <Leader>} <esc>`>a}<esc>`<i{<esc>
vnoremap <Leader>" <esc>`>a"<esc>`<i"<esc>
vnoremap <Leader>' <esc>`>a'<esc>`<i'<esc>
vnoremap <Leader>` <esc>`>a`<esc>`<i`<esc>
" }

" Folding {
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

" EasyMotion {
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
"}

" --> About moving splits :
map <a-h> <C-W>h
map <a-j> <C-W>j
map <a-k> <C-W>k
map <a-l> <C-W>l

" copy to clipboard :
vnoremap <Leader>y "+y

" Bind nohl : Removes highlight of your last search
map  <nowait> <Leader>; :nohl<CR>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>
" Avoid qq recording
nnoremap q <Nop>

" Settings for python-mode
"map <Leader>b oimport ipdb; ipdb.set_trace() # BREAKPOINT<C-c>
map <Leader>i ofrom IPython import embed; embed() # Enter Ipython<C-c>

"}

" Functions {

" Strip whitespace {
function! StripTrailingWhitespace()
    " Preparation: save last search, and cursor position.
    let _s=@/
    let l = line(".")
    let c = col(".")
    " do the business:
    %s/\s\+$//e
    " clean up: restore previous search history, and cursor position
    let @/=_s
    call cursor(l, c)
endfunction
" }

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

    " To specify a different directory in which to place the vimbackup,
    " vimviews, vimundo, and vimswap files/directories, add the following to
    " your .vimrc.before.local file:
    "   let g:spf13_consolidated_directory = <full path to desired directory>
    "   eg: let g:spf13_consolidated_directory = $HOME . '/.vim/'
    if exists('g:spf13_consolidated_directory')
        let common_dir = g:spf13_consolidated_directory . prefix
    else
        let common_dir = parent . '/.' . prefix
    endif

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
"}
call InitializeDirectories()

" Switch auto indent on off {
function! SwitchToggleAutoIndent()
    if &autoindent == "1"
        setlocal noautoindent nocindent nosmartindent indentexpr=
        echo "AutoIndent OFF"
    else
        setlocal autoindent cindent smartindent indentexpr=
        echo "AutoIndent ON"
    endif
endfunction
"}

" Reload Rainbow plugin if available {
" Plugins are loaded after .vimrc files, so in case of sourcing .vimrc files
" while vim is being executed, we need to wrap the plugin into a try - endtry
" to avoid error message at vim start.
function! ActivateRainbow()
    if exists('g:rainbow_active')
        try
            execute ":RainbowToggleOn"
        catch
        endtry
    endif
endfunction
" }
call ActivateRainbow()

" Profile vim  {
function! StartProfiling()
    execute ":profile start profile.log"
    execute ":profile func *"
    execute ":profile file *"
    let b:profiling=1
endfunction

function! EndProfiling()
    execute ":profile pause"
    let b:profiling=0
endfunction

let b:profiling=0
function! ToggleProfiling()
    if b:profiling == 0
        call StartProfiling()
    else
        call EndProfiling()
    endif
endfunction
"}

" About Solarized colors schemes switch {
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
" }}}

" }


