"/ vim: set sw=2 ts=2 sts=2 et tw=78 foldmarker={{{,}}} foldlevel=0 foldmethod=marker spell:
"      _   _   __  __   __    __  _  ___  __   _   _  _  __ __
"     | | | | /  \ \ \_/ /   |  \| || __|/__\ | \ / || ||  V  |
"     | 'V' || /\ | > , <    | | ' || _|| \/ |`\ V /'| || \_/ |
"     !_/ \_!|_||_|/_/ \_\   |_|\__||___|\__/   \_/  |_||_| |_|
"
" Inspired by:
"   - https://github.com/kristijanhusak/neovim-config/blob/master/init.vim
"   - https://github.com/wincent/wincent
"   - https://github.com/awesome-streamers/awesome-streamerrc/tree/master/ThePrimeagen
"
" Should look up into better telescope + lua:
"   - https://github.com/Conni2461/dotfiles/tree/master/.config/nvim

scriptencoding utf-8
set encoding=utf-8   " is the default in neovim though
let mapleader=","

let s:url_plug = "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
let s:path_to_plug_file = $HOME . "/.local/share/nvim/site/autoload/plug.vim"
if !filereadable(s:path_to_plug_file)
  echo "Downloading Plug (plugin manager) ..."
  call system("curl -fLo " . s:path_to_plug_file . " --create-dirs " . s:url_plug)
endif

let s:plugin_dir = $HOME . "/.config/nvim/plugged"
if !isdirectory(s:plugin_dir)
  echo "Creating " . s:plugin_dir
  call system("mkdir -p " . s:plugin_dir)
endif

call plug#begin(s:plugin_dir)

" ----------- System Plugins -----------
Plug 'christoomey/vim-tmux-navigator'              " tmux navigation in love with vim
Plug 'jgdavey/tslime.vim', { 'branch': 'main' }    " Send command from vim to a running tmux session
Plug 'tomtom/tcomment_vim'                         " for contextual comment
Plug 'JoosepAlviste/nvim-ts-context-commentstring' " used by tcomment when disabled syntax

" Tpope is awesome
Plug 'tpope/vim-surround'        " change surrounding easily
Plug 'tpope/vim-repeat'          " better action repeat for vim-surround with .
Plug 'tpope/vim-eunuch'          " sugar for the UNIX shell commands
Plug 'tpope/vim-fugitive'        " Git wrapper for vim

Plug 'Konfekt/FastFold', { 'branch': 'master' } " update folds only when needed, otherwise folds slowdown vim
Plug 'zhimsel/vim-stay'                " adds automated view session creation and restoration whenever editing a buffer
Plug 'junegunn/vim-easy-align'         " easy alignment, better than tabularize
Plug 'jiangmiao/auto-pairs'            " auto pair
Plug 'AndrewRadev/splitjoin.vim'       " easy split join on whole paragraph
Plug 'wellle/targets.vim'              " text object for parenthesis & more !
Plug 'michaeljsmith/vim-indent-object' " text object based on indentation levels.

Plug 'janko/vim-test'            " test at the speed of light

"Plug 'mbbill/undotree', {'on': 'UndotreeToggle'}     " visualize undo tree
"Plug 'majutsushi/tagbar', {'on': 'TagbarToggle'}     " browsing the tags, require ctags
"Plug 'scrooloose/nerdtree', {'on': 'NERDTreeToggle'} " file tree

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzy-native.nvim'
" Plug 'nvim-telescope/telescope-fzf-writer.nvim'

Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }  " Fuzzy Finder
Plug 'junegunn/fzf.vim'


Plug 'justinmk/vim-sneak'  " minimalist motion with 2 keys

Plug 'vim-scripts/loremipsum'         " dummy text generator (:Loremipsum [number of words])
" Plug 'terryma/vim-multiple-cursors'   " nice plugin for multiple cursors


" ----------- User Interface -----------
Plug 'mhinz/vim-startify'        " fancy start screen for Vim
Plug 'kshenoy/vim-signature'     " toggle display marks
Plug 'itchyny/lightline.vim'     " light status line
Plug 'josa42/vim-lightline-coc'  " coc diagnostic in statusline
Plug 'ap/vim-buftabline'         " buffer line
Plug 'lukas-reineke/indent-blankline.nvim', { 'branch': 'lua'}  " indent line

Plug 'rhysd/conflict-marker.vim' " conflict markers for vimdiff
Plug 'luochen1990/rainbow'       " embed parenthesis colors
Plug 'airblade/vim-gitgutter'    " column sign for git changes

Plug 'wincent/loupe'             " better focus on current highlight search
" Plug 'romainl/vim-cool'          " disable highlight on first movement

" Plug 'christianchiarulli/nvcode-color-schemes.vim'
Plug 'morhetz/gruvbox'           " best colorscheme ever
" Plug 'arcticicestudio/nord-vim'  " nice one though

" nerd font need to be installed, see https://github.com/ryanoasis/nerd-fonts#font-installation
" > sudo pacman -S ttf-nerd-fonts-symbols
" > brew tap caskroom/fonts && brew cask install font-hack-nerd-font
Plug 'ryanoasis/vim-devicons'  " nice icons added


" ----------- Completion -----------
Plug 'ervandew/supertab' " use <Tab> for all your insert completion
"Plug 'neoclide/coc.nvim', {'tag': 'v0.0.79', 'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc.nvim', {'branch': 'master', 'do': 'yarn install --frozen-lockfile'}

Plug 'Shougo/neco-vim', {'for': 'vim'}
Plug 'neoclide/coc-neco', {'for': 'vim'}


" ----------- Python -----------
Plug 'tmhedberg/SimpylFold', {'for': 'python'}  " better folds
Plug 'python-mode/python-mode', {'for': 'python'}
Plug 'w0rp/ale', {'for': 'python'}  " general asynchronous syntax checker
" use ale only for python as coc-nvim does it well for the rest


" ----------- FrontEnd -----------
let g:front = ['html', 'vue']
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}       " the one
Plug 'nvim-treesitter/playground'                                 " play with queries
Plug 'nvim-treesitter/nvim-treesitter-textobjects'                " better text objects
" Plug 'p00f/nvim-ts-rainbow'                                       " rainbow parenthesis
Plug 'windwp/nvim-ts-autotag', {'branch': 'main', 'for': g:front} " close html tags

Plug 'mattn/emmet-vim', {'for': g:front}


" ----------- Golang - MarkDown - rst - Terraform - Latex -----------
Plug 'fatih/vim-go', {'for': 'go'}

Plug 'dhruvasagar/vim-table-mode'                    " to easily create tables.
Plug 'junegunn/goyo.vim', { 'on': 'Goyo' }           " Distraction-free writing in Vim
Plug 'junegunn/limelight.vim', { 'on': 'Limelight' } " Dim paragraphs above and below the active paragraph.

Plug 'hashivim/vim-terraform', { 'for': 'terraform' }

Plug 'lervag/vimtex', { 'for': 'tex' }

call plug#end()

" Mappings {{{

" Behaviour fixes {{{

" quick escape:
map <nowait> <Esc> <C-c>
cmap <nowait> <Esc> <C-c>

" Vim command line bindings to match zsh
" ALT + backspace in cmd to delete word, like in terminal
cmap <a-bs> <c-w>

" move beginning of line
cmap <c-a> <c-b>

" Move words
cmap <nowait> <M-b> <S-Left>
cmap <nowait> <M-f> <S-Right>

" Avoid vim history cmd to pop up with q:
nnoremap q: <Nop>

" Avoid entering some weird mode:
map <S-Q> <nop>

" Nvim Terminal
" Make escape work in the Neovim terminal.
tnoremap <Esc> <C-\><C-n>

" Editing sql files, by default ctrl-c is for insert. The Fuck vim ?!
" https://www.reddit.com/r/vim/comments/2om1ib/how_to_disable_sql_dynamic_completion/
let g:omni_sql_no_default_maps = 1

" }}}

" activate spellcheck
map <leader>s :setlocal spell!<CR>

" select all of current paragraph with enter:
nnoremap <return> vip

" For when you forget to sudo.. Really Write the file.
cmap w!! w !sudo tee % >/dev/null
nmap ZZ :wq<cr>

"{{{ Pane motions

" Are already mapped by vim-tmux-navigator
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

" Command mode:
cnoremap <c-h> <c-\><c-n><c-w>h
cnoremap <c-j> <c-\><c-n><c-w>j
cnoremap <c-k> <c-\><c-n><c-w>k
cnoremap <c-l> <c-\><c-n><c-w>l
"}}}

"{{{ Pane operations
" map open terminal
"map <nowait> <leader>n :vsplit \| terminal <CR>

" Buffers switch
map <nowait> œ :bp<cr>
map <nowait> ∑ :bn<cr>

" buffer delete without closing windows :
nmap <silent> ® :bp!\|bd! #<CR>

" Split windows
map <nowait> <leader>l :vs<cr>
map <nowait> ∂ :vs<cr>
map <nowait> <leader>' :sp<cr>
"}}}

"About folding open and close :
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
map <F12> :source ${HOME}/.config/nvim/init.vim<cr>
"}}}

let g:python3_host_prog = $HOME . "/miniconda3/envs/neovim37/bin/python"
let g:python_host_prog = $HOME . "/miniconda3/envs/neovim27/bin/python"

lua require("wax")
