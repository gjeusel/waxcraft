"/ vim: set sw=2 ts=2 sts=2 et tw=78 foldmarker={{{,}}} foldlevel=0 foldmethod=marker spell:
"      _   _   __  __   __    __  _  ___  __   _   _  _  __ __
"     | | | | /  \ \ \_/ /   |  \| || __|/__\ | \ / || ||  V  |
"     | 'V' || /\ | > , <    | | ' || _|| \/ |`\ V /'| || \_/ |
"     !_/ \_!|_||_|/_/ \_\   |_|\__||___|\__/   \_/  |_||_| |_|
"
" Inspired by:
"   - https://github.com/kristijanhusak/neovim-config/blob/master/init.vim
"   - https://github.com/wincent/wincent
"
" Should look up into:
"   - https://github.com/joker1007/dotfiles/blob/master/vimrc
"   - https://github.com/alexlafroscia/dotfiles/blob/master/nvim/init.vim  for js / html

" Specific config in ~/.nvimrc_local
" let g:python3_host_prog = "/Users/jd5584/miniconda3/envs/neovim/bin/python"

scriptencoding utf-8
set encoding=utf-8   " is the default in neovim though
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
  call dein#add('scrooloose/nerdcommenter')       " easy comments
  call dein#add('terryma/vim-smooth-scroll')      " smooth scroll

  " Tpope is awesome
  call dein#add('tpope/vim-surround')             " change surrounding easily
  call dein#add('tpope/vim-repeat')               " better action repeat for vim-surround with .
  call dein#add('tpope/vim-eunuch')               " sugar for the UNIX shell commands

  call dein#add('vim-scripts/loremipsum')         " dummy text generator (:Loremipsum [number of words])
  "call dein#add('easymotion/vim-easymotion')      " easymotion when fedup to think
  call dein#add('skywind3000/asyncrun.vim')       " run async shell commands
  call dein#add('Konfekt/FastFold')               " update folds only when needed, otherwise folds slowdown vim
  call dein#add('zhimsel/vim-stay')               " adds automated view session creation and restoration whenever editing a buffer
  call dein#add('junegunn/vim-easy-align')        " easy alignment, better than tabularize
  call dein#add('majutsushi/tagbar')              " browsing the tags, require ctags
  "call dein#add('mattn/gist-vim')                 " easily upload gist on github
  call dein#add('mbbill/undotree')                " visualize undo tree
  call dein#add('jiangmiao/auto-pairs')           " auto pair
  call dein#add('AndrewRadev/splitjoin.vim')      " easy split join on whole paragraph
  call dein#add('wellle/targets.vim')             " text object for parenthesis & more !

  "call dein#add('terryma/vim-multiple-cursors')   " nice plugin for multiple cursors

  " asynchronous fuzzy finder, should replace ctrlp if ever to work with huuge projects
  " ./install --all so the interactive script doesn't block
  " you can check the other command line options  in the install file
  call dein#add('junegunn/fzf', { 'build': './install --all', 'merged': 0 })
  call dein#add('junegunn/fzf.vim', { 'depends': 'fzf' })

  "call dein#add('wincent/loupe')  " better focus on current highlight search
"}}}

" User Interface {{{
  "call dein#add('scrooloose/nerdtree')  " file tree
  call dein#add('mhinz/vim-startify')  " fancy start screen for Vim
  call dein#add('kshenoy/vim-signature')  " toggle display marks
  call dein#add('itchyny/lightline.vim')  " light status line
  call dein#add('ap/vim-buftabline')  " buffer line
  call dein#add('Yggdroot/indentLine')  " thin indent line
  call dein#add('rhysd/conflict-marker.vim') " conflict markers for vimdiff
  call dein#add('luochen1990/rainbow')  " embed parenthesis colors
  "call dein#add('altercation/vim-colors-solarized')  " prefered colorscheme
  call dein#add('morhetz/gruvbox') " other nice colorscheme
  "call dein#add('chriskempson/base16-vim')

  " nerd font need to be installed, see https://github.com/ryanoasis/nerd-fonts#font-installation
  " > sudo pacman -S ttf-nerd-fonts-symbols
	" > brew tap caskroom/fonts && brew cask install font-hack-nerd-font
  call dein#add('ryanoasis/vim-devicons')  " nice icons added
  "call dein#add('blueyed/vim-diminactive') " dim inactive windows
" }}}

" Other languages syntax highlight {{{
  call dein#add('LnL7/vim-nix')  " for .nix
  call dein#add('cespare/vim-toml')  " syntax for .toml
  call dein#add('tmux-plugins/vim-tmux')  " syntax highlight for .tmux.conf file
  call dein#add('posva/vim-vue')  " syntax highlight for .vue file
"}}}

" Git {{{
  call dein#add('airblade/vim-gitgutter') " column sign for git changes
  call dein#add('tpope/vim-fugitive') " Git wrapper for vim
  call dein#add('tpope/vim-rhubarb')  " GitHub extension for fugitive.vim
  "call dein#add('jreybert/vimagit', {'on_cmd': ['Magit', 'MagitOnly']}) " magit for vim
" }}}

" markdown & rst & grammar checker {{{
  call dein#add('dhruvasagar/vim-table-mode')  " to easily create tables.
  call dein#add('rhysd/vim-grammarous')  " grammar checker
  call dein#add('junegunn/goyo.vim')  "  Distraction-free writing in Vim

  " plugin that adds asynchronous Markdown preview to Neovim
  " > cargo build --release   # should be run in vim-markdown-composer after
  " installation
  "call dein#add('euclio/vim-markdown-composer', {'build': 'cargo build --release'})
  "call dein#add('plasticboy/vim-markdown')
" }}}

" Completion {{{
  call dein#add('ervandew/supertab') " use <Tab> for all your insert completion
  call dein#add('Shougo/deoplete.nvim')  " async engine

  "call dein#add('Shougo/neoinclude.vim')  " completion framework for neocomplete/deoplete
  call dein#add('Shougo/neco-vim') " for vim

  call dein#add('zchee/deoplete-jedi', {'on_ft': 'python'}) " for python
  call dein#add('zchee/deoplete-go', {'on_ft': 'go'})  " for golang
  call dein#add('carlitux/deoplete-ternjs', {'on_ft': ['javascript', 'html', 'css']})  " for javascript

  call dein#add('Shougo/echodoc.vim') " displays function signatures from completions in the command line.
" }}}

" Code Style {{{
  call dein#add('w0rp/ale')  " general asynchronous syntax checker
  "call dein#add('editorconfig/editorconfig-vim')  " EditorConfig plugin for Vim
"}}}

" Python {{{
  call dein#add('tmhedberg/SimpylFold', {'on_ft': 'python'})  " better folds
  call dein#add('davidhalter/jedi-vim', {'on_ft': ['python', 'markdown', 'rst']})
  call dein#add('python-mode/python-mode', {'on_ft': 'python'})
"}}}

" Javascript, Html & CSS {{{
  "call dein#add('othree/html5.vim')  " HTML5 omnicomplete and syntax
  "call dein#add('yaniswang/HTMLHint', {'on_ft': 'html'})  " html

  call dein#add('ternjs/tern_for_vim', {'on_ft': 'javascript'})
  " cd ~/.config/nvim/repos/github.com/ternjs/tern_for_vim && npm install tern

  call dein#add('ap/vim-css-color', {'on_ft': 'css'})  " change bg color in css for colors
  call dein#add('tmhedberg/matchit', {'on_ft': 'html'})  " % for matching tag

  call dein#add('rstacruz/sparkup')  " for html auto generation
  call dein#add('mattn/emmet-vim', {'on_ft': ['html', 'javascript', 'css']}) " for html - CSS - javascript
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

    "map <nowait><leader>f <Plug>(easymotion-bd-f)

    "map <nowait><Leader>l <Plug>(easymotion-lineforward)
    "map <nowait><Leader>j <Plug>(easymotion-j)
    "map <nowait><Leader>k <Plug>(easymotion-k)
    "map <nowait><Leader>h <Plug>(easymotion-linebackward)

    "" beginning of words :
    "map <nowait><leader>z <Plug>(easymotion-w)
    "map <nowait><leader>Z <Plug>(easymotion-b)

    "" end of words :
    "map <nowait><leader>e <Plug>(easymotion-e)
    "map <nowait><leader>E <Plug>(easymotion-ge)
endfunction
autocmd VimEnter * call MapEasymotionInit()
" }}}

" Easy Align {{{
" used to tabularize map:
vmap <leader>t <Plug>(EasyAlign)
" }}}

" Smooth Scroll {{{
noremap <silent> <c-u> :call smooth_scroll#up(&scroll, 0, 2)<CR>
noremap <silent> <c-d> :call smooth_scroll#down(&scroll, 0, 2)<CR>
noremap <silent> <c-b> :call smooth_scroll#up(&scroll*2, 0, 4)<CR>
noremap <silent> <c-f> :call smooth_scroll#down(&scroll*2, 0, 4)<CR>
" }}}

" lightline {{{
" https://github.com/itchyny/lightline.vim/issues/87
let g:lightline = {'colorscheme': 'gruvbox'}

let g:lightline.inactive = {
    \ 'left': [ [ 'mode', 'paste' ],
    \           [ 'readonly', 'modified' ] ],
    \ 'right': [ [ 'lineinfo' ],
    \            [ 'percent' ],
    \            [ 'absolutepath', 'filetype' ] ] }

let g:lightline.active = {
    \ 'left': [ [ 'mode', 'paste' ],
    \           [ 'readonly', 'modified' ] ],
    \ 'right': [ [ 'lineinfo' ],
    \            [ 'percent' ],
    \            [ 'absolutepath', 'filetype' ] ] }

" }}}

" fzf {{{
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number '.shellescape(<q-args>), 0,
  \   <bang>0 ? fzf#vim#with_preview({'options': '--no-hscroll'},'up:60%')
  \           : fzf#vim#with_preview({'options': '--no-hscroll'},'right:50%'),
  \   <bang>0)

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

function! s:find_git_root()
  return system('git rev-parse --show-toplevel 2> /dev/null')[:-2]
endfunction

function! FzfOmniFiles()
    let is_git = system('git status')
    if v:shell_error
        execute 'Files'
    else
        execute 'Files' s:find_git_root()
    endif
endfunction

function! AgOmniFiles()
  let is_git = system('git status')
  if v:shell_error
    execute 'Ag'
  else
    let s:current_dir = getcwd()
    execute 'cd' s:find_git_root()
    execute 'Ag'
    execute 'cd' s:current_dir
  endif
endfunction

nmap <leader>a :call AgOmniFiles()<CR>
nmap <leader>c :BCommits<CR>
nmap <leader>p :call FzfOmniFiles()<CR>
nmap <C-p> :call FzfOmniFiles()<CR>
nmap <leader>b :Buffers<CR>

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


" }}}

" Grammarous
nmap <leader>gr :GrammarousCheck <cr>
" Goyo
let g:goyo_width = 120
nmap <leader>go :Goyo <cr>

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

" make sure the autocompletion will actually trigger using the omnifuncs set later on
if !exists('g:deoplete#omni#input_patterns')
  let g:deoplete#omni#input_patterns = {}
endif

let g:deoplete#enable_ignore_case = 1
let g:deoplete#enable_smart_case = 1

" set multiple options:
call deoplete#custom#option({
      \ 'auto_complete_delay': 0,
      \ 'max_list': 5,
      \ })
      "\ 'auto_refresh_delay': -1,
      "\ 'min_patter_length': 2,
      "\ 'refresh_always': v:false,
      "\ 'ignore_sources': {'python': 'numpy'},
      "\ 'num_processes': 2,

"" Disable the candidates in Comment syntaxes.
"call deoplete#custom#source('_', 'disable_syntaxes', ['Comment'])


let g:echodoc#enable_at_startup = 1
let g:echodoc#enable_force_overwrite = 1

let g:deoplete#file#enable_buffer_path=1
call deoplete#custom#source('buffer', 'mark', 'ℬ')
call deoplete#custom#source('omni', 'mark', '⌾')
call deoplete#custom#source('file', 'mark', '')
call deoplete#custom#source('jedi', 'mark', '🐍')
call deoplete#custom#source('neosnippet', 'mark', '')
call deoplete#custom#source('ultisnips', 'mark', '')
call deoplete#custom#source('LanguageClient', 'mark', '')

" deoplete jedi for python {{{
let g:deoplete#sources#jedi#server_timeout = 40 " extend time for large pkg
let g:deoplete#sources#jedi#show_docstring = 0  " show docstring in preview window
let g:deoplete#sources#jedi#enable_cache = 1

" Sets the maximum length of completion description text. If this is exceeded, a simple description is used instead
let g:deoplete#sources#jedi#statement_length = 20
"}}}

"autocmd CompleteDone * silent! pclose!
set completeopt-=preview  " if you don't want windows popup
set completeopt+=noinsert " needed so deoplete can auto select the first suggestion

" deoplete ternjs for javascript {{{
let g:deoplete#sources#ternjs#tern_bin = '/usr/local/bin/tern'
" Whether to include the types of the completions in the result data. Default: 0
let g:deoplete#sources#ternjs#types = 1
" Whether to include documentation strings (if found) in the result data.
" Default: 0
let g:deoplete#sources#ternjs#docs = 1

" if using tern_for_vim:
let g:tern#command = ["tern"]
let g:tern#arguments = ["--persistent"]
"}}}

"" Debug mode
"call deoplete#enable_logging('DEBUG', '/tmp/deoplete.log')
"let g:deoplete#sources#jedi#debug_server = 0
"let g:deoplete#enable_profile = 0

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

if (isdirectory(expand("$waxCraft_PATH/tools/snippets/UltiSnips")))
  let g:UltiSnipsSnippetDirectories = [expand("$waxCraft_PATH/tool/snippets/UltiSnips"), "UltiSnips"]
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
let g:pymode_indent = 1 " pep8 indent
let g:pymode_folding = 0 " disable folding to use SimpyFold
let g:pymode_motion = 1  " give jumps to functions / methods / classes

" doc
let g:pymode_doc = 1
let g:pymode_doc_bind = '<leader>k'

" syntax (colors for self keyword for example)
let g:pymode_syntax = 1
let g:pymode_syntax_all = 1
let g:pymode_syntax_slow_sync = 1 " slower syntax sync
let g:pymode_trim_whitespaces = 0 " do not trim unused white spaces on save

" Code completion :
let g:pymode_rope = 0 " disable rope which is slow

" Python code checking :
let g:pymode_lint = 0  " disable it to use ALE

" Breakpoint :
let g:pymode_breakpoint = 0  " disable it for custom

" }}}

" Jedi {{{
" Force python 3
let g:jedi#force_py_version=3

let g:jedi#completions_enabled = 0
let g:jedi#use_tabs_not_buffers = 0  " current default is 1.
let g:jedi#smart_auto_mappings = 0  " disable import completion keyword
let g:jedi#auto_close_doc = 1 " Automatically close preview windows upon leaving insert mode

let g:jedi#auto_initialization = 1 " careful, it set omnifunc that is unwanted
let g:jedi#show_call_signatures = 0  " do show the args of func, use echodoc for it

" buggy:
"let g:jedi#auto_vim_configuration = 0  " set completeopt & rempas ctrl-C to Esc

map <Leader>o o__import__('pdb').set_trace()  # BREAKPOINT<C-c>
map <Leader>i o__import__('IPython').embed()  # Enter Ipython<C-c>

"}}}

" Lint ALE {{{
" Only run linters named in ale_linters settings.
let g:ale_linters_explicit = 1

let g:ale_sign_error = '✖'   " Lint error sign
let g:ale_sign_warning = '⚠' " Lint warning sign

" - alex: helps you find gender favouring, polarising, race related, religion inconsiderate, or other unequal phrasing
let g:ale_linters = {
            \ 'python': ['flake8'],
            \ 'markdown': ['alex', 'proselint', 'writegood'],
            \ 'sh': ['alex', 'proselint', 'writegood'],
            \ 'rst': ['alex', 'proselint', 'writegood'],
            \ 'html': ['alex', 'proselint', 'writegood', 'htmlhint', 'eslint', 'prettier'],
            \ 'javascript': ['htmlhint', 'eslint', 'prettier'],
            \ 'css': ['prettier'],
            \}

"\ 'python': ['autopep8', 'isort', 'black'],
let g:ale_fixers = {
            \ 'python': ['isort', 'yapf'],
            \ 'html': ['prettier'],
            \ 'javascript': ['eslint'],
            \ 'json': ['fixjson'],
            \}


" choice of ignored errors in ~/.config/flake8

"let g:ale_fix_on_save = 0  " always fix at save time

" go to previous error in current windows
map <nowait><silent> <leader>[ <Plug>(ale_previous_wrap)
map <nowait><silent> å <Plug>(ale_previous_wrap)

" go to next error in current windows
map <nowait><silent> <leader>] <Plug>(ale_next_wrap)
map <nowait><silent> ß <Plug>(ale_next_wrap)

nmap <leader>m :ALEFix <cr>
"}}}

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

au BufNewFile,BufRead *.md let g:table_mode_header_fillchar='-'
au BufNewFile,BufRead *.md let g:table_mode_corner_corner='|'
"}}}

" TagBar & UndoTree & NERDTree {{{
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

" Markdown {{{
  let g:markdown_composer_autostart = 0  " do not autostart the server, instead use :ComposerStart
  let g:vim_markdown_conceal = 0
  " should use :ComposerStart & :ComposerOpen
" }}}

" tmux {{{
" Disable tmux navigator when zooming the Vim pane
let g:tmux_navigator_disable_when_zoomed = 1
" }}}

"}}}

" User Interface {{{
filetype plugin indent on
syntax enable

set background=dark

let g:gruvbox_invert_selection=0
"let g:gruvbox_improved_strings=1
let g:gruvbox_improved_warnings=1
colorscheme gruvbox

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

set fillchars=vert:│    " box drawings heavy vertical (U+2503, UTF-8: E2 94 83)
highlight VertSplit ctermbg=none

" Custom Fold Text {{{
function! CustomFoldText(delim)
  "get first non-blank line
  let fs = v:foldstart
  while getline(fs) =~ '^\s*$' | let fs = nextnonblank(fs + 1)
  endwhile
  if fs > v:foldend
      let line = getline(v:foldstart)
  else
      let line = substitute(getline(fs), '\t', repeat(' ', &tabstop), 'g')
  endif

  " indent foldtext corresponding to foldlevel
  let indent = repeat(' ',shiftwidth())
  let foldLevelStr = repeat(indent, v:foldlevel-1)
  let foldLineHead = substitute(line, '^\s*', foldLevelStr, '')

  " size foldtext according to window width
  let w = winwidth(0) - &foldcolumn - (&number ? &numberwidth : 0)
  let foldSize = 1 + v:foldend - v:foldstart

  " estimate fold length
  let foldSizeStr = " " . foldSize . " lines "
  let lineCount = line("$")
  if has("float")
    try
      let foldPercentage = "[" . printf("%4s", printf("%.1f", (foldSize*1.0)/lineCount*100)) . "%] "
    catch /^Vim\%((\a\+)\)\=:E806/	" E806: Using Float as String
      let foldPercentage = printf("[of %d lines] ", lineCount)
    endtry
  endif

  " build up foldtext
  let foldLineTail = foldSizeStr . foldPercentage
  let lengthTail = strwidth(foldLineTail)
  let lengthHead = w - (lengthTail + indent)

  if strwidth(foldLineHead) > lengthHead
    let foldLineHead = strpart(foldLineHead, 0, lengthHead-2) . '..'
  endif

  let lengthMiddle = w - strwidth(foldLineHead.foldLineTail)

  " truncate foldtext according to window width
  let expansionString = repeat(a:delim, lengthMiddle)

  let foldLine = foldLineHead . expansionString . foldLineTail
  return foldLine
endfunction
autocmd BufEnter * set foldtext=CustomFoldText('\ ')
"}}}

if has('linebreak')
  let &showbreak='⤷ '   " arrow pointing downwards then curving rightwards (u+2937, utf-8: e2 a4 b7)
endif

let g:indentLine_color_gui = '#343d46'  " indent line color got indentLine plugin

" columns
set colorcolumn=100 " Show vertical bar at column 100
au Filetype python set colorcolumn=100 " do it again for python overriden by some plugin
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

" Backup, swap, undo & sessions{{{
if (!isdirectory(expand("$HOME/.vim/backup")))
  call system(expand("mkdir -p $HOME/.vim/backup"))
endif
set backup                              " Backups are nice ...
set backupdir=~/.vim/backup/

if (!isdirectory(expand("$HOME/.vim/undo")))
  call system(expand("mkdir -p $HOME/.vim/undo"))
endif
if has('persistent_undo')
  set undofile              " So is persistent undo ...
  set undolevels=1000       " Maximum number of changes that can be undone
  set undoreload=10000      " Maximum number lines to save for undo on a buffer reload
  set undodir=~/.vim/undo/
endif

if (!isdirectory(expand("$HOME/.vim/swap")))
  call system(expand("mkdir -p $HOME/.vim/swap"))
endif
set directory=~/.vim/swap/

if has('mksession')
  if (!isdirectory(expand("$HOME/.vim/view")))
    call system(expand("mkdir -p $HOME/.vim/view"))
  endif
  set viewdir=~/.vim/view
  set viewoptions=folds,cursor,unix,slash " Better Unix / Windows compatibility
endif
" }}}

" Searching
set ignorecase " searches are case insensitive...
set smartcase  " ... unless they contain at least one capital letter

" edit file search path ignore
set wildignore+=**.egg-info/**
set wildignore+=**__pycache__/**

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
au BufRead,BufNewFile *.py setlocal shiftwidth=4 tabstop=4 softtabstop=4 textwidth=79

" Other
au BufNewFile,BufRead *.snippets set filetype=snippets foldmethod=marker
au BufNewFile,BufRead *.sh set filetype=sh foldlevel=0 foldmethod=marker
au BufNewFile,BufRead *.nix set filetype=nix
au BufNewFile,BufRead Filetype vim setlocal tabstop=2 foldmethod=marker
au BufNewFile,BufRead *.json set filetype=json
au BufNewFile,BufRead *.txt set filetype=sh
au BufNewFile,BufRead cronfile set filetype=sh
au BufNewFile,BufRead .gitconfig set filetype=conf
au BufNewFile,BufRead *.conf set filetype=config

" html:
au BufNewFile,BufRead *.html set shiftwidth=2 tabstop=2 softtabstop=2
au BufNewFile,BufRead *.html set foldmethod=syntax expandtab nowrap

" Git
au Filetype gitcommit setlocal spell textwidth=72

" Switch to the current file directory when a new buffer is opened
au BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif

" Keep fold under cursor open at write time for python files:
autocmd BufWritePost *.py normal! zv

" Open all unfolded if git file type:
autocmd Filetype git normal! zR
"}}}

" Mappings {{{

" Behaviour fixes {{{

" quick escape:
map <nowait> <Esc> <C-c>
cmap <nowait> <Esc> <C-c>

" ALT + backspace in cmd to delete word, like in terminal
cmap <a-bs> <c-w>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>

" Avoid entering some weird mode:
map <S-Q> <nop>

" Nvim Terminal
" Make escape work in the Neovim terminal.
tnoremap <Esc> <C-\><C-n>

" }}}

" select all of current paragraph with enter:
nnoremap <return> vip

" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null

"{{{ Pane motions

" Are alredy mapped by vim-tmux-navigator
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
"}}}

"{{{ Pane operations
" map open terminal
"map <nowait> <leader>n :vsplit \| terminal <CR>

" Buffers switch
map <nowait> <leader>. :bp<cr>
map <nowait> œ :bp<cr>
map <nowait> <leader>/ :bn<cr>
map <nowait> ∑ :bn<cr>

" buffer delete without closing windows :
nmap <silent> <leader>\ :bp\|bd! #<CR>
nmap <silent> ® :bp\|bd! #<CR>

" Split windows
map <nowait> <leader>l :vs<cr>
map <nowait> ∂ :vs<cr>
map <nowait> <leader>' :sp<cr>
"}}}

"{{{ GoTo

" Jedi for python
autocmd FileType python let g:jedi#goto_command = ""
autocmd FileType python let g:jedi#goto_assignments_command = "<leader>g"
autocmd FileType python let g:jedi#goto_definitions_command = "<leader>d"
autocmd FileType python let g:jedi#documentation_command = "<leader>k"
autocmd FileType python let g:jedi#usages_command = "<leader>n"
"autocmd FileType python let g:jedi#completions_command = "<C-Space>"
autocmd FileType python let g:jedi#rename_command = "<leader>r"
"}}}

" tern javascript
autocmd FileType javascript nmap <leader>d :TernDef<cr>
autocmd FileType javascript nmap <leader>k :TernDoc<cr>
autocmd FileType javascript nmap <leader>n :TernRefs<cr>
autocmd FileType javascript nmap <leader>r :TernRename<cr>
autocmd FileType javascript nmap <leader>j :TernType<cr>

" About folding open and close :
nnoremap <Space> za
vnoremap <Space> za

" Remap some motions:
noremap <nowait> w w
noremap <nowait> W b
noremap <nowait> e e
noremap <nowait> E ge

" copy to clipboard :
vnoremap <Leader>y "+y

" I never use the s in normal mode, so let substitue on pattern:
vnoremap s :s/

" easy save:
map <C-s> :w<CR>

" easy no hl
nmap <leader>; :nohl<cr>

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

" Times choices:
"set ttimeoutlen=10 timeoutlen=500

"" improve quick escape from insertion mode:
"augroup FastEscape
"  autocmd!
"  au InsertEnter * set timeoutlen=0
"  au InsertLeave * set timeoutlen=500
"augroup END

" local config
if !empty(glob("~/.nvimrc_local"))
    source ~/.nvimrc_local
endif
