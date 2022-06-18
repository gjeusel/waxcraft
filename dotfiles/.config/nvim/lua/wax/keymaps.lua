--------- Behaviour fixes ---------
inoremap("<C-e>", "<End>")
inoremap("<C-a>", "<Home>")

-- quick escape:
-- noremap('inc', '<Esc>', '<C-c>', { nowait = true })

-- vim command line bindings to match zsh
cnoremap("<a-bs>", "<c-w>") -- ALT + backspace in cmd to delete word, like in terminal
cnoremap("<alt-bs>", "<c-w>") -- ALT + backspace in cmd to delete word, like in terminal
-- cmap('<a-left>', '<c-left>')  -- ALT + left to act like CTRL + left

cmap("<c-a>", "<c-b>") -- move to beginning of line
cmap("<M-b>", "<S-Left>", { nowait = true }) -- move left word
cmap("<M-f>", "<S-Right", { nowait = true }) -- move right word

-- Avoid vim history cmd to pop up with q:
nnoremap("q:", "<Nop>")

-- Avoid entering some weird ex mode: https://github.com/neovim/neovim/issues/15054
keymap("n", "<S-q>", "<Nop>")

-- Make escape work in the Neovim terminal
tnoremap("<Esc>", "<C-\\><C-n>")

-- select current paragraph with enter:
nnoremap("<return>", "vip")

-- For when you forget to sudo.. Really Write the file.
vim.api.nvim_exec("cmap w!! w !sudo tee % >/dev/null", false)

-- Editing sql files, by default ctrl-c is for insert. The Fuck vim ?!
-- https://www.reddit.com/r/vim/comments/2om1ib/how_to_disable_sql_dynamic_completion/
vim.g.omni_sql_no_default_maps = 1

--------- Commands Maps ---------
-- source current lua file
nmap("<leader>sf", ":luafile %<CR>")

-- activate/deactivate spellcheck
nmap("<leader>ss", ":setlocal spell!<CR>")

-- set no highlight
nmap("<leader>;", ":nohl<cr>")

-- copy to clipboard :
vnoremap("<leader>y", '"+y')

-- Easy save
nmap("<C-s>", ":w<CR>")

--------- Opiniated (re-)Maps ---------

-- remap motions
noremap("nv", "w", "w", { nowait = true })
noremap("nv", "W", "b", { nowait = true })
noremap("nv", "e", "e", { nowait = true })
noremap("nv", "E", "ge", { nowait = true })

-- Y to copy until the end of the line instead of the full line like yy
nnoremap("Y", "yg_")

-- I never use the s in normal mode, so let substitue on pattern:
vnoremap("s", ":s/")

-- -- Buffers switch
-- keymap("in", "œ", "<cmd>bp<cr>", { nowait = true }) -- option + q
-- keymap("in", "∑", "<cmd>bn<cr>", { nowait = true }) -- option + w
--
-- -- delete buffer without closing pane: (option + r)
-- vim.api.nvim_exec("nnoremap <silent>® :bp!\\|bd! #<CR>", false)
-- -- nnoremap('®', ':bp!\\|bd! #<CR>', { silent = true }) -- not working
--
-- -- delete all buffers except current: (option + R)
-- nnoremap("‰", "<cmd>BufOnly<cr>", { silent = true })

-- Split panes
nnoremap("<leader>l", "<cmd>vs<cr>", { nowait = true })
nnoremap("<leader>'", "<cmd>sp<cr>", { nowait = true })

-- Open / Close  fold
nnoremap("<Space>", "za")
vnoremap("<Space>", "za")

--------- Language Specific Mapping ---------
-- Python
vim.cmd([[
function! SetPyModeMappings()
  map <buffer> <Leader>o o__import__("pdb").set_trace()  # BREAKPOINT<C-c>
  map <buffer> <Leader>O O__import__("pdb").set_trace()  # BREAKPOINT<C-c>
  "import pdb; pdb.break_on_setattr('session_id')(container._sa_instance_state.__class__)
  "map <Leader>i ofrom ptpython.repl import embed; embed()  # Enter ptpython<C-c>
endfunction

augroup python_pymode_mappings
  au Filetype python call SetPyModeMappings()
augroup end
]])

-- Front
vim.cmd([[
function! SetFrontendMappings()
  map <buffer> <Leader>o odebugger  // BREAKPOINT<C-c>
  map <buffer> <Leader>O Odebugger  // BREAKPOINT<C-c>
endfunction
augroup frontend_mappings
  au Filetype vue,typescript,javascript,typescriptreact,javascriptreact call SetFrontendMappings()
augroup end
]])

-- quick fix list
nnoremap("]q", "<cmd>cnext<cr>")
nnoremap("[q", "<cmd>cprev<cr>")
nnoremap("[w", "<cmd>ccl<cr>") -- quite quick fix list
