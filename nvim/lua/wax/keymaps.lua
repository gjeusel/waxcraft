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
    cnoreabbrev Cq cq
    cnoreabbrev Wa wa
    cnoreabbrev Wq wq
    cnoreabbrev Wqa wqa
    cnoreabbrev wq1 wq!
    cnoreabbrev Wq1 wq!
    cnoreabbrev wQ1 wq!
    cnoreabbrev WQ1 wq!
    cnoreabbrev Wqa1 wqa!
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

-- remap ctrl+d and ctrl+u to trick neovim into not adding those movements into the jump list
vim.keymap.set("n", "<C-D>", "<C-D>", { nowait = true })
vim.keymap.set("n", "<C-U>", "<C-U>", { nowait = true })

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
vim.keymap.set(
  "i",
  "<S-CR>",
  "<CR>",
  { nowait = true, remap = false, desc = "Force a clear line return" }
)
vim.keymap.set(
  "i",
  "<C-CR>",
  "<CR>",
  { nowait = true, remap = false, desc = "Force a clear line return" }
)

-- For when you forget to sudo.. Really Write the file.
-- vim.keymap.set("c", "w!!", "w !sudo tee % >/dev/null")

-- source current lua file
vim.keymap.set("n", "<leader>sf", ":luafile %<CR>")

-- activate/deactivate spellcheck
-- vim.keymap.set("n", "<leader>ss", ":setlocal spell!<CR>")

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
vim.keymap.set({ "n", "v" }, "<Space>", function()
  vim.cmd("silent! normal! za")
end, { desc = "Toggle fold" })

-- quick fix list
vim.keymap.set("n", "]q", function()
  local ok = pcall(vim.cmd, "cnext")
  if not ok then
    vim.cmd("cfirst")
  end
  vim.cmd([[normal! zz]])
end, { desc = "Goto next qflist item (cycling)" })

vim.keymap.set("n", "[q", function()
  local ok = pcall(vim.cmd, "cprev")
  if not ok then
    vim.cmd("clast")
  end
  vim.cmd([[normal! zz]])
end, { desc = "Goto prev qflist item (cycling)" })

vim.keymap.set("n", "q][", function()
  vim.cmd("silent! cclose")
end)

-- vim.keymap.set("n", "]q", "<cmd>cnext<cr>")
-- vim.keymap.set("n", "[q", "<cmd>cprev<cr>")

vim.keymap.set("n", "[w", "<cmd>ccl<cr>") -- quite quick fix list

-- copy in register current buffer absolute filepath
vim.keymap.set("n", "<leader>fF", function()
  local fname = vim.fn.expand("%:t")
  vim.fn.setreg("+", fname)
end, { desc = "Yank current buffer filename" })

vim.keymap.set("n", "<leader>ff", function()
  local abspath = vim.api.nvim_buf_get_name(0)
  if abspath == "" then
    vim.notify("No file associated with current buffer", vim.log.levels.WARN)
    return
  end

  local Path = require("wax.path")

  local filename = vim.fn.expand("%:t")
  local options = { abspath, filename }

  local workspace = find_root_package()
  if workspace then
    table.insert(options, 1, Path:new(abspath):make_relative(workspace).path)
  end

  local git_root = find_root_monorepo()
  if git_root then
    table.insert(options, 1, Path:new(abspath):make_relative(git_root).path)
  end

  vim.ui.select(options, { prompt = "Select filepath to copy > " }, function(selected)
    if selected then
      vim.fn.setreg("+", selected)
      vim.notify(("Copied to clipboard: %s"):format(selected))
    end
  end)
end, { desc = "Propose current file paths to copy in register" })

local function _get_python_parts()
  vim.cmd([[normal! "wyiw]])
  local word_under_cursor = vim.fn.getreg('"')

  local abspath = vim.api.nvim_buf_get_name(0)
  local workspace = find_root_dir(abspath, { "pyproject.toml" })
  if not workspace then
    return
  end

  local Path = require("wax.path")
  local relpath = Path:new(abspath):make_relative(workspace).path
  if not string.match(relpath, ".py$") then
    return
  end

  local module = string.gsub(relpath, "/", "."):gsub("%.py$", "")

  return module, word_under_cursor
end

vim.keymap.set("n", "<leader>yP", function()
  local module, word_under_cursor = _get_python_parts()

  vim.fn.setreg("+", ("from %s import %s"):format(module, word_under_cursor))
end, { desc = "Yank current file python word as import" })

vim.keymap.set("n", "<leader>yp", function()
  local module, word_under_cursor = _get_python_parts()
  vim.fn.setreg("+", ("%s.%s"):format(module, word_under_cursor))
end, { desc = "Yank current file python word as modle" })

-- set foldlevel
for i = 0, 9, 1 do
  vim.keymap.set("n", ("<leader>f%s"):format(i), function()
    vim.cmd(("set foldlevel=%s"):format(i))
    vim.cmd("silent! zO")
  end)
end

-- find vim help quickly
vim.keymap.set("n", "<leader>fH", function()
  vim.cmd([[normal! "wyiw]])
  local word = vim.fn.getreg('"')
  vim.cmd("vert h " .. word)
end, {
  desc = "Vertical split help for word under cursor",
})

------ menus ------
vim.keymap.set("n", "<leader>sm", function()
  local options = {
    ["checkhealth vim.lsp"] = function()
      vim.cmd("checkhealth vim.lsp")
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
      vim.cmd("stopinsert")
      options[selected]()
    end
  end)
end)
