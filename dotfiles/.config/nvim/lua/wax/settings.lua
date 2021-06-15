vim.g.mapleader = ","

vim.o.mouse = "a"           -- Automatically enable mouse usage
vim.o.number = true         -- display line number column
vim.o.relativenumber = true -- relative line number
vim.o.ruler = true          -- Show the cursor position all the time
-- vim.o.cursorline = true     -- Highlight the line of the cursor
-- vim.o.guicursor=nil         -- disable cursor-styling
-- vim.o.noshowmode = true     -- do not put a message on the cmdline for the mode ('insert', 'normal', ...)

vim.o.scrolljump=5          -- Lines to scroll when cursor leaves screen
vim.o.scrolloff=3           -- Have some context around the current line always on screen
vim.o.virtualedit="onemore" -- Allow for cursor beyond last character
vim.o.hidden = true         -- Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
vim.o.foldenable = true     -- Open all folds while not set.
vim.o.splitright = true     -- split at the right of current buffer (left default behaviour)
vim.o.splitbelow = true     -- split at the below of current buffer (top default behaviour)
vim.o.autochdir = true      -- working directory is always the same as the file you are editing

vim.o.updatetime = 50       -- frequency to apply Autocmd events -> low for nvim-ts-context-commentstring
vim.cmd [[set shortmess+=c]]        -- don't pass messages to ins-completion-menu
vim.o.completeopt = "menuone,noselect"


vim.o.spelllang="en_us"     -- activate vim spell checking
-- vim.o.nospell = true

vim.cmd [[set fillchars=vert:│]]    -- box drawings heavy vertical (U+2503, UTF-8: E2 94 83)

vim.cmd [[
if has('linebreak')
  let &showbreak='⤷ '   " arrow pointing downwards then curving rightwards (u+2937, utf-8: e2 a4 b7)
endif
]]

-- cmdline
vim.o.wildmenu = true                       -- Show list instead of just completing
vim.cmd([[set wildmode=list:longest,full]]) -- Command <Tab> completion, list matches, then longest common part, then all.

-- Whitespace
-- vim.o.nowrap = nil                                          -- don't wrap lines
vim.o.tabstop = 2
vim.o.expandtab = true                                      -- a tab is two spaces
vim.o.shiftwidth = 2                                          -- an autoindent (with <<) is two spaces
vim.o.list = true                                           -- show the following:
vim.cmd([[set listchars=tab:›\ ,trail:•,extends:#,nbsp:.]]) -- Highlight problematic whitespace

-- -- Backup, swap, undo & sessions
-- for directory in [--backup--, --swap--, --undo--, --view--]
--   silent! call mkdir($HOME . --/.vim/-- . directory, --p--)
-- endfor
--
-- vim.o.backup                              -- Backups are nice ...
-- vim.o.backupdir=~/.vim/backup/
-- vim.o.directory=~/.vim/swap/
--
-- if has('persistent_undo')
--   vim.o.undofile              -- So is persistent undo ...
--   vim.o.undolevels=1000       -- Maximum number of changes that can be undone
--   vim.o.undoreload=10000      -- Maximum number lines to save for undo on a buffer reload
--   vim.o.undodir=~/.vim/undo/
-- endif
--
-- if has('mksession')
--   vim.o.viewdir=~/.vim/view
--   vim.o.viewoptions-=options  -- needed by vim-stay
--   --vim.o.viewoptions=folds,cursor,unix,slash -- Better Unix / Windows compatibility
-- endif

-- Searching
vim.o.ignorecase = true -- searches are case insensitive...
vim.o.smartcase = true  -- ... unless they contain at least one capital letter

-- edit file search path ignore
vim.cmd([[
set wildignore+=**.egg-info/**
set wildignore+=**__pycache__/**
set wildignore+=**node_modules/**
]])

-- Clipboard
vim.cmd([[
if has('clipboard')
  if has('unnamedplus') " When possible use + register for copy-paste
    vim.o.clipboard+=unnamedplus
  endif
endif
]])

-- -- activate per project settings
-- vim.o.exrc = true  -- allows loading local EXecuting local RC files
-- vim.o.secure = true  -- disallows the use of :autocmd, shell and write commands in local


local HOME = vim.fn.expand("$HOME")
vim.g.python3_host_prog = HOME .. "/miniconda3/envs/neovim37/bin/python"
vim.g.python_host_prog = HOME .. "/miniconda3/envs/neovim27/bin/python"
