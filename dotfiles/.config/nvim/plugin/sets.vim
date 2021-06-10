filetype plugin indent on
syntax enable

set background=dark

set mouse=a             " Automatically enable mouse usage
set mousehide           " Hide the mouse cursor while typing
set number              " display line number column
set relativenumber      " relative line number
set ruler               " Show the cursor position all the time
"set cursorline          " Highlight the line of the cursor
"set guicursor=          " disable cursor-styling
set noshowmode          " do not put a message on the cmdline for the mode ('insert', 'normal', ...)

set scrolljump=5        " Lines to scroll when cursor leaves screen
set scrolloff=3         " Have some context around the current line always on screen
set virtualedit=onemore " Allow for cursor beyond last character
set hidden              " Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
set foldenable          " Open all folds while not set.
set splitright          " split at the right of current buffer (left default behaviour)
set splitbelow          " split at the below of current buffer (top default behaviour)
set autochdir           " working directory is always the same as the file you are editing

set updatetime=10       " frequency to apply Autocmd events -> low for nvim-ts-context-commentstring
set shortmess+=c        " don't pass messages to ins-completion-menu

set spelllang=en_us     " activate vim spell checking
set nospell

set fillchars=vert:│    " box drawings heavy vertical (U+2503, UTF-8: E2 94 83)

if has('linebreak')
  let &showbreak='⤷ '   " arrow pointing downwards then curving rightwards (u+2937, utf-8: e2 a4 b7)
endif

" columns
set colorcolumn=100                    " Show vertical bar at column 100

" cmdline
set wildmenu                    " Show list instead of just completing
set wildmode=list:longest,full  " Command <Tab> completion, list matches, then longest common part, then all.

" Whitespace
set nowrap                                     " don't wrap lines
set tabstop=2 expandtab                        " a tab is two spaces
set shiftwidth=2                               " an autoindent (with <<) is two spaces
set list                                       " show the following:
set listchars=tab:›\ ,trail:•,extends:#,nbsp:. " Highlight problematic whitespace
set expandtab                                  " Spaces are used in indents"

" Backup, swap, undo & sessions {{{
for directory in ["backup", "swap", "undo", "view"]
  silent! call mkdir($HOME . "/.vim/" . directory, "p")
endfor

set backup                              " Backups are nice ...
set backupdir=~/.vim/backup/
set directory=~/.vim/swap/

if has('persistent_undo')
  set undofile              " So is persistent undo ...
  set undolevels=1000       " Maximum number of changes that can be undone
  set undoreload=10000      " Maximum number lines to save for undo on a buffer reload
  set undodir=~/.vim/undo/
endif

if has('mksession')
  set viewdir=~/.vim/view
  set viewoptions-=options  " needed by vim-stay
  "set viewoptions=folds,cursor,unix,slash " Better Unix / Windows compatibility
endif
" }}}

" Searching
set ignorecase " searches are case insensitive...
set smartcase  " ... unless they contain at least one capital letter

" edit file search path ignore
set wildignore+=**.egg-info/**
set wildignore+=**__pycache__/**
set wildignore+=**node_modules/**

" Clipboard
if has('clipboard')
  if has('unnamedplus') " When possible use + register for copy-paste
    set clipboard+=unnamedplus
  endif
endif

" " activate per project settings
" set exrc  " allows loading local EXecuting local RC files
" set secure  " disallows the use of :autocmd, shell and write commands in local
