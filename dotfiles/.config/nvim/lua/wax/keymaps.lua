local kmap = vim.keymap.set

-- Reload
kmap("n", "<leader>fr", function()
  -- reload snippets
  require("wax.plugins.luasnip").reload()
end)

-- Fix common typos
vim.cmd([[
    cnoreabbrev W! w!
    cnoreabbrev W1 w!
    cnoreabbrev w1 w!
    cnoreabbrev Q! q!
    cnoreabbrev Q1 q!
    cnoreabbrev q1 q!
    cnoreabbrev Qa! qa!
    cnoreabbrev Qall! qall!
    cnoreabbrev Wa wa
    cnoreabbrev Wq wq
    cnoreabbrev wQ wq
    cnoreabbrev WQ wq
    cnoreabbrev wq1 wq!
    cnoreabbrev Wq1 wq!
    cnoreabbrev wQ1 wq!
    cnoreabbrev WQ1 wq!
    cnoreabbrev W w
    cnoreabbrev Q q
    cnoreabbrev Qa qa
    cnoreabbrev Qall qall
]])

--------- Behaviour fixes ---------
kmap("i", "<C-e>", "<End>")
kmap("i", "<C-a>", "<Home>")

-- vim command line bindings to match zsh
kmap("c", "<a-bs>", "<c-w>") -- ALT + backspace in cmd to delete word, like in terminal
kmap("c", "<alt-bs>", "<c-w>") -- ALT + backspace in cmd to delete word, like in terminal
-- kmap('c', '<a-left>', '<c-left>')  -- ALT + left to act like CTRL + left

kmap("c", "<c-a>", "<c-b>") -- move to beginning of line
kmap("c", "<M-b>", "<S-Left>", { nowait = true }) -- move left word
kmap("c", "<M-f>", "<S-Right", { nowait = true }) -- move right word

-- Avoid vim history cmd to pop up with q:
kmap("n", "q:", "<Nop>")

-- Avoid entering some weird ex mode: https://github.com/neovim/neovim/issues/15054
kmap("n", "<S-q>", "<Nop>")

-- Make escape work in the Neovim terminal
kmap("t", "<Esc>", "<C-\\><C-n>")

-- ThePrimeagen is right ...
-- Why ? Because else "<C-c>" does not trigger InsertLeave autcmd
vim.keymap.set("i", "<C-c>", "<Esc>")

--
----------- Opiniated KeyMaps -----------

-- select current paragraph with enter:
kmap("n", "<return>", "vip")

-- For when you forget to sudo.. Really Write the file.
kmap("c", "w!!", "w !sudo tee % >/dev/null")

-- source current lua file
kmap("n", "<leader>sf", ":luafile %<CR>")

-- activate/deactivate spellcheck
kmap("n", "<leader>ss", ":setlocal spell!<CR>")

-- set no highlight
-- kmap("n", "<leader>;", ":nohl<cr>") -- done in hlslens plugin

-- copy to clipboard :
kmap("v", "<leader>y", '"+y')

-- Easy save
kmap("n", "<C-s>", ":w<CR>")

-- remap motions
kmap({ "n", "v" }, "w", "w", { nowait = true })
kmap({ "n", "v" }, "W", "b", { nowait = true, remap = false })
kmap({ "n", "v" }, "gw", "W", { nowait = true, remap = false })

kmap({ "n", "v" }, "e", "e", { nowait = true })
kmap({ "n", "v" }, "E", "ge", { nowait = true, remap = false })
kmap({ "n", "v" }, "ge", "E", { nowait = true, remap = false })

-- Y to copy until the end of the line instead of the full line like yy
kmap({ "n", "v" }, "Y", "yg_")

-- dD to delete without putting in register
kmap({ "n" }, "dD", '"_dd')

-- I never use the substitute mode, so let's use it for search & replace on range:
kmap("v", "s", ":s/")

-- Paste without losing what's in register
kmap("v", "p", '"_dP') -- kmap("v", "<leader>p", '"_dP')

-- From the ThePrimeagen (recenter on vertical movements)
-- kmap("n", "<C-d>", "<C-d>zz")  -- laggy
-- kmap("n", "<C-u>", "<C-u>zz")
-- kmap("n", "n", "nzzzv")
-- kmap("n", "N", "Nzzzv")

-- -- Buffers maps (now defined in barbar plugin)
-- kmap({"i", "n"}, "œ", "<cmd>bp<cr>", { nowait = true }) -- option + q
-- kmap({"i", "n"}, "∑", "<cmd>bn<cr>", { nowait = true }) -- option + w
-- vim.api.nvim_exec("nnoremap <silent>® :bp!\\|bd! #<CR>", false) -- delete buffer without closing pane (option + r )
-- kmap("n", "‰", "<cmd>BufOnly<cr>", { silent = true }) -- delete all buffers except current (option + d)

-- Split panes
kmap("n", "<leader>l", "<cmd>vs<cr>", { nowait = true })
kmap("n", "<leader>'", "<cmd>sp<cr>", { nowait = true })

-- Open / Close  fold
kmap({ "n", "v" }, "<Space>", "za")

-- quick fix list
kmap("n", "]q", "<cmd>cnext<cr>")
kmap("n", "[q", "<cmd>cprev<cr>")
kmap("n", "[w", "<cmd>ccl<cr>") -- quite quick fix list

-- copy in register current buffer absolute filepath
kmap("n", "<leader>fp", function()
  local fname = vim.fn.expand("%:t")
  vim.fn.setreg("+", fname)
end)
kmap("n", "<leader>fP", function()
  local fpath = vim.api.nvim_buf_get_name(0)
  vim.fn.setreg("+", fpath)
end)

-- set foldlevel
for i = 0, 5, 1 do
  kmap("n", ("<leader>f%s"):format(i), function()
    vim.cmd(("set foldlevel=%s"):format(i))
    vim.cmd("silent! zO")
  end)
end

--------- Language Specific Mapping ---------
-- See autocmds
