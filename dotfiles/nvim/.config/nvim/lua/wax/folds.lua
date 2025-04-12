-- Folds in NeoVim are not receiving the love they deserve.
--
-- issue fold API: https://github.com/neovim/neovim/issues/19226
--
-- issue fold update before treesitter: https://github.com/neovim/neovim/issues/14977
-- but not sure about this one, as removing

vim.o.foldlevelstart = 99 -- always open all folds on open
vim.o.foldlevel = 99 -- always open all folds on open
vim.o.foldenable = true -- Open all folds while not set.
-- vim.o.foldminlines = 3 -- Min lines before fold.
-- vim.o.foldcolumn = "1" -- fold column width

-- TODO: Sometimes folds disappear on format or get out of sync
-- https://github.com/nvim-treesitter/nvim-treesitter/issues/1424
-- https://github.com/neovim/neovim/issues/14977
-- Fixed by conform.

vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldmethod = "expr"

_G.custom_fold_text = function()
  local line = vim.fn.getline(vim.v.foldstart)
  if vim.list_contains({ "{" }, line:gsub("%s", "")) then
    line = ("%s %s"):format(line, vim.fn.getline(vim.v.foldstart + 1):match("^%s*(.-)%s*$"))
  end

  local num_lines = vim.v.foldend - vim.v.foldstart + 1
  local maxchars = tonumber(vim.o.colorcolumn) or 100
  local suffix = string.format("%s lines ↩", num_lines)
  local spaces = string.rep(" ", maxchars - (line:len() + suffix:len()))
  return line .. spaces .. suffix
end
vim.opt.foldtext = "v:lua.custom_fold_text()"

-- Taken from https://github.com/kevinhwang91/nvim-ufo

local function goPreviousStartFold()
  local function getCurLnum()
    return vim.api.nvim_win_get_cursor(0)[1]
  end

  local cnt = vim.v.count1
  local winView = vim.fn.winsaveview()
  local curLnum = getCurLnum()
  vim.cmd("norm! m`")
  local previousLnum
  local previousLnumList = {}
  while cnt > 0 do
    vim.cmd([[keepj norm! zk]])
    local tLnum = getCurLnum()
    vim.cmd([[keepj norm! [z]])
    if tLnum == getCurLnum() then
      local foldStartLnum = vim.fn.foldclosed(tLnum)
      if foldStartLnum > 0 then
        vim.cmd(("keepj norm! %dgg"):format(foldStartLnum))
      end
    end
    local nextLnum = getCurLnum()
    while curLnum > nextLnum do
      tLnum = nextLnum
      table.insert(previousLnumList, nextLnum)
      vim.cmd([[keepj norm! zj]])
      nextLnum = getCurLnum()
      if nextLnum == tLnum then
        break
      end
    end
    if #previousLnumList == 0 then
      break
    end
    if #previousLnumList < cnt then
      cnt = cnt - #previousLnumList
      curLnum = previousLnumList[1]
      previousLnum = curLnum
      vim.cmd(("keepj norm! %dgg"):format(curLnum))
      previousLnumList = {}
    else
      while cnt > 0 do
        previousLnum = table.remove(previousLnumList)
        cnt = cnt - 1
      end
    end
  end
  vim.fn.winrestview(winView)
  if previousLnum then
    vim.cmd(("norm! %dgg_"):format(previousLnum))
  end
end

vim.keymap.set("n", "zK", "zk", { noremap = true })
vim.keymap.set("n", "zk", goPreviousStartFold)
