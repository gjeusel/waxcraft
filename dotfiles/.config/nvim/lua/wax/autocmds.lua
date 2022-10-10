-- Handle Views
local group_view = "Views"
vim.api.nvim_create_augroup(group_view, { clear = true })
vim.api.nvim_create_autocmd("BufRead", { pattern = "*", command = "silent! loadview" })
vim.api.nvim_create_autocmd({"BufWrite", "BufLeave"}, { pattern = "*", command = "silent! mkview" })

------------- Local Settings depending on FileType -------------
--
local group_ft_settings = "FileType Local Settings"
vim.api.nvim_create_augroup(group_ft_settings, { clear = true })

local map_ft_local_settings = {
  yaml = "shiftwidth=2 tabstop=2 softtabstop=2 foldminlines=3",
  gitcommit = "spell viewoptions= viewdir=",
  git = "syntax=on nofoldenable",
  vim = "tabstop=2 foldmethod=marker",
  ["*sh"] = "nofoldenable",
  markdown = "spell textwidth=140 nofoldenable", -- "wrap wrapmargin=2"
  toml = "textwidth=140 nofoldenable",
  json = "foldmethod=syntax",
  edgeql = "commentstring=#%s",
  --
  python = "shiftwidth=4 tabstop=4 softtabstop=4",
  --
  html = "foldmethod=syntax nowrap shiftwidth=2 tabstop=2 softtabstop=2",
  [{ "vue", "typescript", "typescriptreact", "javascript", "javascriptreact" }] = "foldminlines=3",
}

for filetype, settings in pairs(map_ft_local_settings) do
  vim.api.nvim_create_autocmd("FileType", {
    group = group_ft_settings,
    pattern = filetype,
    command = ("setlocal %s"):format(settings),
  })
end

local function insert_new_line_in_current_buffer(str, opts)
  local default_opts = { delta = 1 }
  opts = vim.tbl_deep_extend("keep", opts or {}, default_opts)

  local pos = vim.api.nvim_win_get_cursor(0)
  local n_line = pos[1]

  local n_insert_line = n_line + opts.delta

  -- deduce indent for line:
  local space
  if is_module_available("nvim-treesitter.indent") then
    local ts_indent = require("nvim-treesitter.indent")
    local n_space = ts_indent.get_indent(n_insert_line)
    space = string.rep(" ", n_space)
  else
    local buf_content = vim.api.nvim_buf_get_lines(0, n_insert_line - 1, n_insert_line - 1, false)
    local cur_line_content = buf_content[1]
    space = string.match(cur_line_content, "%s*")
  end

  local str_added = ("%s%s"):format(space, str)

  vim.api.nvim_buf_set_lines(0, n_insert_line - 1, n_insert_line - 1, false, { str_added })
  vim.api.nvim_win_set_cursor(0, { n_insert_line, pos[2] })
end

-- Python
vim.api.nvim_create_autocmd("FileType", {
  group = group_ft_settings,
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      insert_new_line_in_current_buffer('__import__("pdb").set_trace()  # BREAKPOINT')
    end)
    vim.keymap.set("n", "<leader>O", function()
      insert_new_line_in_current_buffer(
        '__import__("pdb").set_trace()  # BREAKPOINT',
        { delta = 0 }
      )
    end)
  end,
})

-- Frontend
vim.api.nvim_create_autocmd("FileType", {
  group = group_ft_settings,
  pattern = { "vue", "typescript", "javascript", "typescriptreact", "javascriptreact" },
  callback = function()
    vim.keymap.set("n", "<leader>o", function()
      insert_new_line_in_current_buffer("debugger  // BREAKPOINT")
    end)
    vim.keymap.set("n", "<leader>O", function()
      insert_new_line_in_current_buffer("debugger  // BREAKPOINT", { delta = 0 })
    end)
  end,
})

------------- Performances -------------
-- https://www.reddit.com/r/neovim/comments/pz3wyc/comment/heyy4qf/?utm_source=share&utm_medium=web2x&context=3
vim.api.nvim_exec(
  [[
" disable syntax highlighting in big files
function DisableSyntaxTreesitter()
  echo("Big file, disabling syntax, treesitter and folding")
  if exists(':TSBufDisable')
      exec 'TSBufDisable autotag'
      exec 'TSBufDisable highlight'
      exec 'TSBufDisable indent'
      exec 'TSBufDisable incremental_selection'
      exec 'TSBufDisable context_commentstring'
      exec 'TSBufDisable autopairs'
  endif

  setlocal eventignore+=FileType  " disable all filetype autocommands

  setlocal foldmethod=manual
  setlocal foldexpr=
  setlocal nowrap
  "syntax clear
  "syntax off    " hmmm, which one to use?
  "filetype off

  setlocal noundofile
  setlocal noswapfile
  setlocal noloadplugins
endfunction

function EnableFastFeatures()
  " activate some fast tooling
  LspStart
  exec 'setlocal syntax=' . &ft
endfunction

let g:large_file = 512 * 1024

augroup BigFileDisable
  autocmd!
  autocmd BufReadPre,FileReadPre * if getfsize(expand("%")) > g:large_file | exec DisableSyntaxTreesitter() | endif
  autocmd BufEnter * if getfsize(expand("%")) > g:large_file | exec EnableFastFeatures() | endif
augroup END

]],
  false
)
