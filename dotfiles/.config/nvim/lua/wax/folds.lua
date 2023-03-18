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

vim.o.foldmethod = "expr"
vim.o.foldexpr = "nvim_treesitter#foldexpr()" -- replaced by custom

-- TODO: convert it to lua function ?
vim.cmd([[
function! FoldText() abort
  " clear fold from fillchars to set it up the way we want later
  let &l:fillchars = substitute(&l:fillchars,',\?fold:.','','gi')
  let l:numwidth = (v:version < 701 ? 8 : &numberwidth)
  let l:foldtext = ' '.(v:foldend-v:foldstart).' lines folded'.v:folddashes.'¦'
  " let l:endofline = (&textwidth>0 ? &textwidth : 80)
  let l:endofline = 100
  let l:linetext = strpart(getline(v:foldstart),0,l:endofline-strlen(l:foldtext))
  let l:align = l:endofline-strlen(l:linetext)
  setlocal fillchars+=fold:\ 
  return printf('%s%*s', l:linetext, l:align, l:foldtext)
endfunction
]])

vim.cmd("set foldtext=FoldText()")

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
