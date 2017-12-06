" vim: set sw=4 ts=4 sts=4 et tw=78 foldmarker={,} foldlevel=0 foldmethod=marker spell:

if &compatible
  set nocompatible
endif
set runtimepath+=~/.vim/bundle/repos/github.com/Shougo/dein.vim/

" Plugins {
" path to where to store plugins:
if dein#load_state('~/.vim/bundle')
  call dein#begin('~/.vim/bundle')

  " path to plugin manager:
  call dein#add('~/.vim/bundle/repos/github.com/Shougo/dein.vim/')

  " User Interface {
  call dein#add('vim-airline/vim-airline')
  call dein#add('vim-airline/vim-airline-themes')
  " see for patching terminal fonts :
  " https://powerline.readthedocs.org/en/latest/installation/linux.html#font-installation
  let g:airline_powerline_fonts=1
  let g:airline#extensions#tabline#enabled = 1
  let g:airline#extensions#tabline#show_buffers = 1

  call dein#add('altercation/vim-colors-solarized')
  call dein#add('bling/vim-bufferline')
  let g:bufferline_echo = 0 " buffer line at top

  call dein#add('LnL7/vim-nix')

  call dein#add('luochen1990/rainbow')
  let g:rainbow_active = 1 "0 if you want to enable it later via :RainbowToggle
  "}

  " Ack
  call dein#add('mileszs/ack.vim')
  let g:ackprg="ack-grep -H --nocolor --nogroup --column"
  nmap <leader>a :Ack ""<Left>
  nmap <leader>A :Ack <C-r><C-w>

  call dein#add('tpope/vim-fugitive')
  call dein#add('tpope/vim-repeat')
  call dein#add('tpope/vim-surround')

  call dein#add('majutsushi/tagbar')
  call dein#add('scrooloose/nerdcommenter')
  call dein#add('rhysd/conflict-marker.vim')
  call dein#add('vim-scripts/sessionman.vim')
  call dein#add('mbbill/undotree')

  call dein#add('vim-scripts/restore_view.vim')
  set viewoptions=cursor,folds,slash,unix
  " let g:skipview_files = ['*\.vim']

  " Easymotion {
  call dein#add('easymotion/vim-easymotion')
  let g:EasyMotion_do_mapping = 1
  let g:EasyMotion_smartcase = 1
  "}


  call dein#add('Shougo/deoplete.nvim')
  call dein#add('Shougo/neoinclude.vim') " include completion framework
  call dein#add('Shougo/neco-syntax') " syntax source for neocomplete

  call dein#add('SirVer/ultisnips') " snippets engine handle
  call dein#add('honza/vim-snippets') " those are the snippets
  " compatibility deoplete & ultisnipts:
  call deoplete#custom#set('ultisnips', 'matchers', ['matcher_fuzzy'])

  " Python {
  call dein#add('zchee/deoplete-jedi')
  call dein#add('python-mode/python-mode')
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
  " Python code checking :
  let g:pymode_lint = 1
  let g:pymode_lint_on_write = 1
  let g:pymode_lint_checkers = ['pep8', 'pyflakes'] " pep8 code checker
  let g:pymode_lint_ignore = ["E501", "W",] " ignore warning line too long


  " Code completion :
  let g:pymode_rope = 1 " enable rope which is slow
  let g:pymode_rope_completion = 1 " enable completion
  let g:pymode_rope_lookup_project = 0 " do not lookup in parent directories which is slow
  let g:pymode_rope_autoimport = 0

  " use all other features of jedi but completion
  call dein#add('davidhalter/jedi-vim')
  let g:jedi#completions_enabled = 0
  let g:jedi#auto_vim_configuration = 0
  let g:jedi#goto_assignments_command = ''  " dynamically done for ft=python.
  let g:jedi#goto_definitions_command = ''  " dynamically done for ft=python.
  let g:jedi#use_tabs_not_buffers = 0  " current default is 1.
  let g:jedi#smart_auto_mappings = 1
  let g:jedi#auto_close_doc = 1

  call dein#add('tell-k/vim-autopep8')
  let g:autopep8_disable_show_diff=1 " disable show diff windows
  let g:autopep8_ignore="E501" " ignore line too long
  nnoremap <leader>f :Autopep8<CR>
  vnoremap <leader>f :Autopep8<CR>
  "}

  call dein#end()
  call dein#save_state()
endif
"}

" User Interface {
filetype plugin indent on
syntax enable
set background=dark
colorscheme solarized

set mouse=a                 " Automatically enable mouse usage
set mousehide               " Hide the mouse cursor while typing
set number " display line number column
set ruler          " Show the cursor position all the time
set cursorline     " Highlight the line of the cursor
set scrolljump=5                " Lines to scroll when cursor leaves screen
set scrolloff=3    " Have some context around the current line always on screen
set virtualedit=onemore             " Allow for cursor beyond last character
set hidden         " Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
set foldenable                  " Auto fold code

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

" cmdline
set wildmenu                    " Show list instead of just completing
set wildmode=list:longest,full  " Command <Tab> completion, list matches, then longest common part, then all.

" Whitespace
set nowrap                        " don't wrap lines
set tabstop=2                     " a tab is two spaces
set shiftwidth=2                  " an autoindent (with <<) is two spaces
set list " show the following:
set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " Highlight problematic whitespace

" Backup
set backup                  " Backups are nice ...
silent !mkdir ~/.config/nvim/_backup > /dev/null 2>&1
set backupdir=~/.config/nvim/_backup   " where to put backup files
if has('persistent_undo')
  set undofile                " So is persistent undo ...
  set undolevels=1000         " Maximum number of changes that can be undone
  set undoreload=10000        " Maximum number lines to save for undo on a buffer reload
endif

" Temp
silent !mkdir ~/.config/nvim/_temp > /dev/null 2>&1
set directory=~/.config/nvim/_temp     " where to put swap files

" Searching
set ignorecase                    " searches are case insensitive...
set smartcase                     " ... unless they contain at least one capital letter

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
  au BufWritePre * :%s/\s\+$//e

  " Make sure all markdown files have the correct filetype set and setup
  " wrapping and spell check
  function! s:setupWrappingAndSpellcheck()
      set wrap
      set wrapmargin=2
      set textwidth=80
      set spell
  endfunction
  au BufRead,BufNewFile *.{md,md.erb,markdown,mdown,mkd,mkdn,txt} setf markdown | call s:setupWrappingAndSpellcheck()

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
  au BufNewFile,BufRead *.sh set filetype=sh
  au BufNewFile,BufRead *.vimrc* set filetype=vim
  au BufNewFile,BufRead *.vim set filetype=vim
  au BufNewFile,BufRead *.cmake set filetype=cmake
  au BufNewFile,BufRead CMakeLists.txt set filetype=cmake

  " Git
  au Filetype gitcommit setlocal spell textwidth=72

  " Switch to the current file directory when a new buffer is opened
  au BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif

endif

"}

" Behaviour fixes {

" Times choices:
set ttimeoutlen=10
set timeoutlen=150

map <nowait> <Esc> <C-c>
" quick escape from command line with esc :
cmap <nowait> <Esc> <C-c>

" Nvim Terminal
" Make escape work in the Neovim terminal.
tnoremap <Esc> <C-\><C-n>

" Unmapping F1 calling help in vim :
map <F1> <nop>
map <A-F1> <nop>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>
" Avoid qq recording
nnoremap q <Nop>

" }

" Key (re)Mappings {
let mapleader=","

" clear the search highlight
nnoremap <leader>; :nohl<cr>

" select all of current paragraph with enter:
nnoremap <return> (V)

" easier navigation between split windows
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

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

"set ttimeoutlen=-1
map <nowait> <A-a> :bp<cr>
map <nowait> <A-z> :bn<cr>
map <nowait> <A-e> :cn<cr>

" buffer delete without closing windows :
nmap <silent> <A-r> :bp\|bd #<CR>
"}

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


" copy to clipboard :
vnoremap <Leader>y "+y

" source config
map <F12> :source ${HOME}/.config/nvim/init.vim<cr>

" Settings for python-mode
"map <Leader>b oimport ipdb; ipdb.set_trace() # BREAKPOINT<C-c>
map <Leader>i ofrom IPython import embed; embed() # Enter Ipython<C-c>

" Easymotion {
" bd for bidirectional :
map <nowait><leader>s <Plug>(easymotion-bd-w)

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
" }

"}
