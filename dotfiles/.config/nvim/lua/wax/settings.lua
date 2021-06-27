vim.g.mapleader = ","

vim.o.mouse = "a" -- Automatically enable mouse usage
vim.o.number = true -- display line number column
vim.o.relativenumber = true -- relative line number
vim.o.ruler = true -- Show the cursor position all the time
-- vim.o.cursorline = true     -- Highlight the line of the cursor
-- vim.o.guicursor=nil         -- disable cursor-styling
-- vim.o.noshowmode = true     -- do not put a message on the cmdline for the mode ('insert', 'normal', ...)

vim.o.scrolljump = 5 -- Lines to scroll when cursor leaves screen
vim.o.scrolloff = 3 -- Have some context around the current line always on screen
vim.o.virtualedit = "onemore" -- Allow for cursor beyond last character
vim.o.hidden = true -- Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
vim.o.foldenable = true -- Open all folds while not set.
vim.o.splitright = true -- split at the right of current buffer (left default behaviour)
vim.o.splitbelow = true -- split at the below of current buffer (top default behaviour)
vim.o.autochdir = true -- working directory is always the same as the file you are editing

vim.o.backup = true -- Backups are nice ...

vim.o.updatetime = 200 -- frequency to apply Autocmd events -> low for nvim-ts-context-commentstring
vim.api.nvim_exec([[set shortmess+=c]], false) -- don't pass messages to ins-completion-menu
vim.o.completeopt = "menuone,noselect"

vim.o.pyxversion = 3

vim.o.spelllang = "en_us" -- activate vim spell checking
-- vim.o.nospell = true
vim.api.nvim_exec([[set fillchars=vert:│]], false) -- box drawings heavy vertical (U+2503, UTF-8: E2 94 83)
vim.api.nvim_exec(
  [[
if has('linebreak')
  let &showbreak='⤷ '   " arrow pointing downwards then curving rightwards (u+2937, utf-8: e2 a4 b7)
endif
]],
  false
)

-- cmdline
vim.o.wildmenu = true -- Show list instead of just completing
vim.api.nvim_exec([[set wildmode=list:longest,full]], false) -- Command <Tab> completion, list matches, then longest common part, then all.

-- Whitespace
-- vim.o.nowrap = nil                                          -- don't wrap lines
vim.o.tabstop = 2
vim.o.expandtab = true -- a tab is two spaces
vim.o.shiftwidth = 2 -- an autoindent (with <<) is two spaces
vim.o.list = true -- show the following:
vim.api.nvim_exec([[set listchars=tab:›\ ,trail:•,extends:#,nbsp:.]], false) -- Highlight problematic whitespace

-- Backup, swap, undo & sessions
local basedir = vim.fn.expand("$HOME") .. "/.local/share/nvim"

local backupdir = basedir .. "/backup"
vim.fn.mkdir(backupdir, "p")
vim.o.backupdir = backupdir

if vim.fn.has("persistent_undo") == 1 then
  local undodir = basedir .. "/undo"
  vim.fn.mkdir(undodir, "p")
  vim.o.undofile = true -- So is persistent undo ...
  vim.o.undolevels = 1000 -- Maximum number of changes that can be undone
  vim.o.undoreload = 10000 -- Maximum number lines to save for undo on a buffer reload
  vim.o.undodir = undodir
end

if vim.fn.has("mksession") == 1 then
  local viewdir = basedir .. "/view"
  vim.fn.mkdir(viewdir, "p")
  vim.o.viewdir = viewdir
  vim.api.nvim_exec(
    [[
    autocmd BufWrite * mkview
    autocmd BufRead * silent! loadview
    ]],
    false
  )
  -- vim.api.nvim_exec([[set viewoptions=cursor,folds,slash,unix]], false)
  -- vim.api.nvim_exec(
  --   [[set viewoptions-=options]], -- needed by vim-stay
  --   false
  -- )
end

-- Searching
vim.o.ignorecase = true -- searches are case insensitive...
vim.o.smartcase = true -- ... unless they contain at least one capital letter

-- edit file search path ignore
local ignore_file_patterns = { ".egg-info/", "__pycache__/", "node_modules/" }
-- for _, pattern  in ipairs(ignore_file_patterns) do
--   vim.o.wildignore = vim.o.wildignore .. "," .. "**" .. pattern .. "**"
-- end

-- Clipboard
if vim.fn.has("clipboard") == 1 and vim.fn.has("unnamedplus") == 1 then
  vim.o.clipboard = "unnamedplus"
end

-- -- activate per project settings
-- vim.o.exrc = true  -- allows loading local EXecuting local RC files
-- vim.o.secure = true  -- disallows the use of :autocmd, shell and write commands in local

vim.g.python_host_prog = os.getenv("HOME") .. "/opt/miniconda3/envs/nvim27/bin/python"
vim.g.python3_host_prog = os.getenv("HOME") .. "/opt/miniconda3/envs/nvim/bin/python"
