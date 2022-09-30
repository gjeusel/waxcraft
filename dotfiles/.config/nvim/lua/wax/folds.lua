-- Folds in NeoVim are not receiving the love they deserve.
--
-- issue fold API: https://github.com/neovim/neovim/issues/19226
--
-- issue fold update before treesitter: https://github.com/neovim/neovim/issues/14977
-- but not sure about this one, as removing

vim.o.foldlevel = 99 -- always open all folds on open
vim.o.foldenable = true -- Open all folds while not set.
-- vim.o.foldminlines = 3 -- Min lines before fold.

vim.o.foldmethod = "expr"
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()"  -- replaced by custom

-- this method needs to be defined in the autoload directory:
vim.o.foldexpr = "wax#foldexpr()"

local map_cache_bufnr_tsmatches = {}
local memoize_by_bufnr = function(fn)
  return function(bufnr)
    if map_cache_bufnr_tsmatches[bufnr] == nil then
      log.debug(("Storing TS fold results of %s"):format(bufnr))
      map_cache_bufnr_tsmatches[bufnr] = fn(bufnr)
    end
    return map_cache_bufnr_tsmatches[bufnr]
  end
end

local query = safe_require("nvim-treesitter.query")
local parsers = safe_require("nvim-treesitter.parsers")

local find_fold_nodes = function(lang)
  if query.has_folds(lang) then
    return "@fold", "folds"
  elseif query.has_locals(lang) then
    return "@scope", "locals"
  end
end

local gen_fold_match_ranges = function(matches)
  -- start..stop is an inclusive range
  local start_counts = {}
  local stop_counts = {}

  local prev_start = -1
  local prev_stop = -1

  local min_fold_lines = vim.api.nvim_win_get_option(0, "foldminlines")

  for _, match in ipairs(matches) do
    local start, stop, stop_col
    if match.metadata and match.metadata.range then
      start, _, stop, stop_col = unpack(match.metadata.range)
    else
      start, _, stop, stop_col = match.node:range()
    end

    if stop_col == 0 then
      stop = stop - 1
    end

    local fold_length = stop - start + 1
    local should_fold = fold_length > min_fold_lines

    -- Fold only multiline nodes that are not exactly the same as previously met folds
    -- Checking against just the previously found fold is sufficient if nodes
    -- are returned in preorder or postorder when traversing tree
    if should_fold and not (start == prev_start and stop == prev_stop) then
      start_counts[start] = (start_counts[start] or 0) + 1
      stop_counts[stop] = (stop_counts[stop] or 0) + 1
      prev_start = start
      prev_stop = stop
    end
  end

  return { start = start_counts, stop = stop_counts }
end

local get_fold_indic_by_line = memoize_by_bufnr(function(bufnr)
  log.debug(("Generating TS fold results of %s"):format(bufnr))
  local max_fold_level = vim.api.nvim_win_get_option(0, "foldnestmax")
  local trim_level = function(level)
    return math.min(level, max_fold_level)
  end

  local parser = parsers.get_parser(bufnr)

  if not parser then
    return {}
  end

  local matches = query.get_capture_matches_recursively(bufnr, find_fold_nodes)

  local ranges = gen_fold_match_ranges(matches)

  local levels = {}
  local current_level = 0

  -- We now have the list of fold opening and closing, fill the gaps and mark where fold start
  for lnum = 0, vim.api.nvim_buf_line_count(bufnr) do
    local prefix = ""

    local last_trimmed_level = trim_level(current_level)
    current_level = current_level + (ranges.start[lnum] or 0)
    local trimmed_level = trim_level(current_level)
    current_level = current_level - (ranges.stop[lnum] or 0)
    local next_trimmed_level = trim_level(current_level)

    -- Determine if it's the start/end of a fold
    -- NB: vim's fold-expr interface does not have a mechanism to indicate that
    -- two (or more) folds start at this line, so it cannot distinguish between
    --  ( \n ( \n )) \n (( \n ) \n )
    -- versus
    --  ( \n ( \n ) \n ( \n ) \n )
    -- If it did have such a mechanism, (trimmed_level - last_trimmed_level)
    -- would be the correct number of starts to pass on.
    if trimmed_level - last_trimmed_level > 0 then
      prefix = ">"
    elseif trimmed_level - next_trimmed_level > 0 then
      -- Ending marks tend to confuse vim more than it helps, particularly when
      -- the fold level changes by at least 2; we can uncomment this if
      -- vim's behavior gets fixed.
      -- prefix = "<"
      prefix = ""
    end

    levels[lnum + 1] = prefix .. tostring(trimmed_level)
  end

  return levels
end)

local M = {}

function M.get_fold_indic(lnum)
  if not parsers.has_parser() or not lnum then
    return "0"
  end

  local buf = vim.api.nvim_get_current_buf()

  local levels = get_fold_indic_by_line(buf) or {}

  local level = levels[lnum] or "0"
  return level
end

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

local fold_augroup = "fold-update"
vim.api.nvim_create_augroup(fold_augroup, { clear = true })

-- Auto-update folds on insert leave, and auto-disable folds update while inserting
local map_foldmethod_bufnr = {}

vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  group = fold_augroup,
  pattern = "*",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    map_foldmethod_bufnr[bufnr] = vim.b.foldmethod -- store buf foldmethod
    vim.opt_local.foldmethod = "manual"
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "CursorHold", "User LspRequest" }, {
  group = fold_augroup,
  pattern = "*",
  callback = function()
    -- maybe apply stored buf foldmethod:
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.tbl_contains(vim.tbl_keys(map_foldmethod_bufnr), bufnr) then
      vim.opt_local.foldmethod = map_foldmethod_bufnr[bufnr]
    else
      vim.opt_local.foldmethod = "expr"
    end
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "User LspRequest" }, {
  group = fold_augroup,
  pattern = "*",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    if map_cache_bufnr_tsmatches[bufnr] ~= nil then
      log.debug(("Clearing TS fold cache for %s"):format(bufnr))
      table.remove(map_cache_bufnr_tsmatches, bufnr)
    end
    -- vim.opt_local.foldlevel = 99
    -- print("Text changed")
    -- vim.cmd("doautocmd")
    -- -- maybe apply stored buf foldmethod:
    -- local bufnr = vim.api.nvim_get_current_buf()
    -- if vim.tbl_contains(vim.tbl_keys(map_foldmethod_bufnr), bufnr) then
    --   vim.opt_local.foldmethod = map_foldmethod_bufnr[bufnr]
    -- else
    --   vim.opt_local.foldmethod = "expr"
    -- end
  end,
})

-- vim.keymap.set("n", "zx", function()
--   vim.cmd("startinsert")
--   vim.cmd("stopinsert")
--   print("Updated folds")
-- end, {
--   noremap = true,
--   silent = true,
-- })

return M
