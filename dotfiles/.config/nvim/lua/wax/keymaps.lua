-- Reload
vim.keymap.set("n", "<leader>fr", function()
  -- reload snippets
  require("wax.plugcfg.luasnip").reload()
end, { desc = "Reload Luasnip snippets" })

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
    cnoreabbrev E e
]])

--------- Behaviour fixes ---------
vim.keymap.set("i", "<C-e>", "<End>")
vim.keymap.set("i", "<C-a>", "<Home>")

-- vim command line bindings to match zsh
vim.keymap.set("c", "<a-bs>", "<c-w>") -- ALT + backspace in cmd to delete word, like in terminal
vim.keymap.set("c", "<alt-bs>", "<c-w>") -- ALT + backspace in cmd to delete word, like in terminal
-- vim.keymap.set('c', '<a-left>', '<c-left>')  -- ALT + left to act like CTRL + left

vim.keymap.set("c", "<c-a>", "<c-b>", { nowait = true, desc = "Move to beginning of line" }) -- move to beginning of line
vim.keymap.set("c", "<M-b>", "<S-Left>", { nowait = true, desc = "Move left word" }) -- move left word
vim.keymap.set("c", "<M-f>", "<S-Right>", { nowait = true, desc = "Move right word" }) -- move right word

-- Avoid vim history cmd to pop up with q:
vim.keymap.set("n", "q:", "<Nop>")

-- Avoid entering some weird ex mode: https://github.com/neovim/neovim/issues/15054
vim.keymap.set("n", "<S-q>", "<Nop>")

-- ThePrimeagen is right ...
-- Why ? Because else "<C-c>" does not trigger InsertLeave autcmd
vim.keymap.set("i", "<C-c>", "<Esc>")

vim.keymap.set({ "n", "x", "t" }, "<C-c>", "<Esc>") -- try out replace <C-c> wrong habit

--
----------- Opiniated KeyMaps -----------

-- select current paragraph with enter:
vim.keymap.set("n", "<return>", "vip")

-- For when you forget to sudo.. Really Write the file.
-- vim.keymap.set("c", "w!!", "w !sudo tee % >/dev/null")

-- source current lua file
vim.keymap.set("n", "<leader>sf", ":luafile %<CR>")

-- activate/deactivate spellcheck
vim.keymap.set("n", "<leader>ss", ":setlocal spell!<CR>")

-- set no highlight
-- vim.keymap.set("n", "<leader>;", ":nohl<cr>") -- done in hlslens plugin

-- copy to clipboard :
vim.keymap.set("v", "<leader>y", '"+y')

-- Easy save
vim.keymap.set("n", "<C-s>", ":w<CR>")

-- remap motions
vim.keymap.set({ "n", "v" }, "w", "w", { nowait = true })
vim.keymap.set({ "n", "v" }, "W", "b", { nowait = true, remap = false })
vim.keymap.set({ "n", "v" }, "gw", "W", { nowait = true, remap = false })

vim.keymap.set({ "n", "v" }, "e", "e", { nowait = true })
vim.keymap.set({ "n", "v" }, "E", "ge", { nowait = true, remap = false })
vim.keymap.set({ "n", "v" }, "ge", "E", { nowait = true, remap = false })

-- Y to copy until the end of the line instead of the full line like yy
vim.keymap.set({ "n", "v" }, "Y", "yg_")

-- dD to delete without putting in register
vim.keymap.set({ "n" }, "dD", '"_dd')

-- I never use the substitute mode, so let's use it for search & replace on range:
vim.keymap.set("v", "s", ":s/")

-- Keep my cursor at the same position while joining lines
vim.keymap.set("n", "J", "mzJ`z")

-- Paste without losing what's in register (Fails in case of block highlight)
vim.keymap.set("v", "<leader>p", '"_dP')

-- From the ThePrimeagen (recenter on vertical movements)
-- vim.keymap.set("n", "<C-d>", "<C-d>zz")  -- laggy
-- vim.keymap.set("n", "<C-u>", "<C-u>zz")
-- vim.keymap.set("n", "n", "nzzzv")
-- vim.keymap.set("n", "N", "Nzzzv")

-- vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
-- vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
-- vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
-- vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

-- -- Buffers maps (now defined in barbar plugin)
-- vim.keymap.set({"i", "n"}, "œ", "<cmd>bp<cr>", { nowait = true }) -- option + q
-- vim.keymap.set({"i", "n"}, "∑", "<cmd>bn<cr>", { nowait = true }) -- option + w
-- vim.api.nvim_exec("nnoremap <silent>® :bp!\\|bd! #<CR>", false) -- delete buffer without closing pane (option + r )
-- vim.keymap.set("n", "‰", "<cmd>BufOnly<cr>", { silent = true }) -- delete all buffers except current (option + d)

-- To debug, map the possibility to exit insert mode without trigger of events
-- vim.keymap.set("i", "<C-z>", function ()
--   vim.cmd("stopinsert")
-- end)

-- Split panes
vim.keymap.set("n", "<leader>l", "<cmd>vs<cr>", { nowait = true })
vim.keymap.set("n", "<leader>'", "<cmd>sp<cr>", { nowait = true })

-- Open / Close  fold
vim.keymap.set({ "n", "v" }, "<Space>", "za")

-- quick fix list
vim.keymap.set("n", "]q", function()
  vim.cmd("cnext!")
  vim.cmd([[normal! zz]])
end, { desc = "Goto next qflist item" })

vim.keymap.set("n", "[q", function()
  vim.cmd("cprev!")
  vim.cmd([[normal! zz]])
end, { desc = "Goto prev qflist item" })

-- vim.keymap.set("n", "]q", "<cmd>cnext<cr>")
-- vim.keymap.set("n", "[q", "<cmd>cprev<cr>")

vim.keymap.set("n", "[w", "<cmd>ccl<cr>") -- quite quick fix list

-- copy in register current buffer absolute filepath
vim.keymap.set("n", "<leader>yf", function()
  local fname = vim.fn.expand("%:t")
  vim.fn.setreg("+", fname)
end, { desc = "Yank current buffer filename" })

vim.keymap.set("n", "<leader>yF", function()
  local fpath = vim.api.nvim_buf_get_name(0)
  vim.fn.setreg("+", fpath)
end, { desc = "Yank current buffer absolute filepath" })

vim.keymap.set("n", "<leader>yp", function()
  local abspath = vim.api.nvim_buf_get_name(0)
  local workspace = find_root_dir(abspath)
  if not workspace then
    return
  end

  local Path = require("plenary.path")
  local relpath = Path:new(abspath):make_relative(workspace)
  if not string.match(relpath, ".py$") then
    return
  end

  vim.fn.setreg("+", string.gsub(relpath, "/", "."):gsub("%.py$", ""))
end, { desc = "Yank current file python module" })

-- set foldlevel
for i = 0, 5, 1 do
  vim.keymap.set("n", ("<leader>f%s"):format(i), function()
    vim.cmd(("set foldlevel=%s"):format(i))
    vim.cmd("silent! zO")
  end)
end

-- find vim help quickly
vim.keymap.set("n", "<leader>fh", function()
  vim.cmd([[normal! "wyiw]])
  local word = vim.fn.getreg('"')
  vim.cmd("vert h " .. word)
end, {
  desc = "Vertical split help for word under cursor",
})

--------- Different menues ---------
vim.keymap.set("n", "<leader>sm", function()
  local options = {
    ["LspInfo"] = function()
      vim.cmd("LspInfo")
    end,
    ["Mason UI"] = function()
      require("mason.ui").open()
    end,
    ["Lazy Home"] = function()
      require("lazy").home()
    end,
    ["Lazy Profile"] = function()
      require("lazy").profile()
    end,
    ["Null-ls Info"] = function()
      vim.cmd("NullLsInfo")
    end,
    ["checkhealth"] = function()
      vim.cmd("checkhealth")
    end,
  }

  local sorted_options = vim.tbl_keys(options)
  table.sort(sorted_options, function(left, right)
    return left < right
  end)

  vim.ui.select(sorted_options, { prompt = "Open Menu > " }, function(selected)
    if selected then
      options[selected]()
    end
  end)
end)
