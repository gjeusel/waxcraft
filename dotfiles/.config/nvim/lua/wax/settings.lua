vim.keymap.set({ "n", "x", "v" }, ",,", ",", { remap = false })
vim.g.mapleader = ","

vim.o.mouse = "a" -- Automatically enable mouse usage
vim.o.number = true -- display line number column
vim.o.relativenumber = true -- relative line number
-- vim.o.termguicolors = true -- enable 24bit colors

-- vim.o.laststatus = 3  -- global statusline

vim.o.conceallevel = 0 -- don't conceal anything
vim.o.colorcolumn = "100" -- Show vertical bar at column 100
vim.o.signcolumn = "yes" -- always show sign column
vim.o.ruler = true -- Show the cursor position all the time
-- vim.o.cursorline = true     -- Highlight the line of the cursor
-- vim.o.guicursor=nil         -- disable cursor-styling
-- vim.o.noshowmode = true     -- do not put a message on the cmdline for the mode ('insert', 'normal', ...)

-- vim.o.laststatus = false  -- hide status bar
-- vim.o.cmdheight = 0  -- hide cmdline  -- waiting for https://github.com/neovim/neovim/issues/20380

vim.o.scrolljump = 5 -- Lines to scroll when cursor leaves screen
vim.o.scrolloff = 8 -- Have some context around the current line always on screen
vim.o.virtualedit = "onemore" -- Allow for cursor beyond last character
vim.o.hidden = true -- Allow backgrounding buffers without writin them, and remember marks/undo for backgrounded buffers
vim.o.splitright = true -- split at the right of current buffer (left default behaviour)
vim.o.splitbelow = true -- split at the below of current buffer (top default behaviour)
vim.o.autochdir = true -- working directory is always the same as the file you are editing
vim.o.textwidth = 0 -- avoid auto line return while typing

vim.o.updatetime = 50 -- frequency to apply Autocmd events -> low for nvim-ts-context-commentstring
vim.api.nvim_exec([[set shortmess+=cs]], false) -- don't pass messages to ins-completion-menu
vim.o.completeopt = "menuone,noselect"

vim.o.pumheight = 5 -- max completion popup menu height

vim.o.matchpairs = "(:),{:},[:],<:>,':',\":\""
-- vim.o.matchpairs = { "(:)", "{:}", "[:]", "<:>", "':'", '":"' } -- behavior of '%'

vim.o.pyxversion = 3

vim.o.spellang = "en_us" -- activate vim spell checking
vim.o.spelloptions = "camel,noplainbuffer"
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

-- Whitespace & Indent settings
-- vim.o.nowrap = nil                                          -- don't wrap lines
vim.o.tabstop = 2
vim.o.expandtab = true -- a tab is two spaces
vim.o.shiftwidth = 2 -- an autoindent (with <<) is two spaces
-- vim.o.smartindent = false -- prevent indent on python commented line
vim.o.autoindent = false -- do not use previous line indent

vim.o.list = true -- show the following:
vim.api.nvim_exec([[set listchars=tab:›\ ,trail:•,extends:#,nbsp:.]], false) -- Highlight problematic whitespace

-- Backup, swap, undo & sessions
local basedir = vim.fn.stdpath("data")

if vim.fn.has("persistent_undo") == 1 then
  local undodir = basedir .. "/undo"
  vim.fn.mkdir(undodir, "p")
  vim.o.undodir = undodir

  vim.o.undofile = true -- So is persistent undo ...
  vim.o.undolevels = 1000 -- Maximum number of changes that can be undone
  vim.o.undoreload = 10000 -- Maximum number lines to save for undo on a buffer reload

  -- useless backup & swapfile as we will use persisted undo
  vim.o.swapfile = false
  vim.o.backup = false
  vim.o.writebackup = false
  vim.o.backupdir = nil
else
  vim.o.swapfile = true
  vim.o.backup = true

  -- swapfile
  vim.o.directory = basedir .. "/swap"

  local backupdir = basedir .. "/backup"
  vim.fn.mkdir(backupdir, "p")
  vim.o.backupdir = backupdir
end

if vim.fn.has("mksession") == 1 then
  local viewdir = basedir .. "/view"
  vim.fn.mkdir(viewdir, "p")
  vim.o.viewdir = viewdir
  vim.o.viewoptions = "cursor,slash,unix"
end

-- NetRW (https://shapeshed.com/vim-netrw/)
vim.g.netrw_banner = 0 -- no need for banner
vim.g.netrw_liststyle = 3 -- prefered style
vim.g.netrw_sort_by = "name"
vim.g.netrw_sort_direction = "reverse"

-- Searching
vim.o.ignorecase = true -- searches are case insensitive...
vim.o.smartcase = true -- ... unless they contain at least one capital letter
vim.o.incsearch = 1 -- show the pattern matches while typing

-- cmdline autocomplete
vim.o.wildignore = "**/*.egg-info,**/__pycache__,**/node_modules" -- ignore those pattern
vim.o.wildignorecase = true -- ignore case on :e
vim.o.wildmenu = false
vim.o.wildoptions = "fuzzy"
vim.o.wildmode = "list:longest,full" -- first list matches, then longest common part, then all.

-- Clipboard
if vim.fn.has("clipboard") == 1 and vim.fn.has("unnamedplus") == 1 then
  vim.o.clipboard = "unnamedplus"
end

-- -- activate per project settings
-- vim.o.exrc = true  -- allows loading local EXecuting local RC files
-- vim.o.secure = true  -- disallows the use of :autocmd, shell and write commands in local

-- Performances
vim.o.synmaxcol = 128

-- Python config
-- vim.g.python_host_prog = os.getenv("HOME") .. "/opt/miniconda3/envs/nvim27/bin/python"
vim.g.python3_host_prog = waxopts.python3

-- enable debug (neovim logfile is in $NVIM_LOG_FILE)
if waxopts.loglevel == "debug" then
  vim.o.debug = "msg"
  vim.o.verbosefile = vim.fn.stdpath("cache") .. "/nvim-verbosefile.log"
  vim.o.verbose = 1 -- 16 is max
end

--
------- Disable Some Builtins -------

-- Disable providers we do not care a about
vim.g.loaded_python_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- Disable some in built plugins completely
local disabled_built_ins = {
  -- "netrw",
  -- "netrwPlugin",
  -- "netrwSettings",
  -- "netrwFileHandlers",
  "gzip",
  "zip",
  "zipPlugin",
  "tar",
  "tarPlugin",
  "getscript",
  "getscriptPlugin",
  "vimball",
  "vimballPlugin",
  "2html_plugin",
  "logipat",
  "rrhelper",
  "spellfile_plugin",
  "fzf",
  "matchit",
  "matchparen",
}
for _, plugin in pairs(disabled_built_ins) do
  vim.g["loaded_" .. plugin] = 1
end

--
------- Behaviour fixes -------

-- While editing sql files, by default ctrl-c is for insert.
-- The Fuck vim ?!
-- https://www.reddit.com/r/vim/comments/2om1ib/how_to_disable_sql_dynamic_completion/
vim.g.omni_sql_no_default_maps = 1
