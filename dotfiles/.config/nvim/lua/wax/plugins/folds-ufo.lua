-- vim.o.foldcolumn = "1"
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = -1
vim.o.foldenable = true

vim.keymap.set("n", "zR", require("ufo").openAllFolds)
vim.keymap.set("n", "zM", require("ufo").closeAllFolds)

vim.keymap.set("n", "zK", "zk", { noremap = true })
vim.keymap.set("n", "zk", require("ufo").goPreviousStartFold)

local fold_fmt_handler = function(virtText, lnum, endLnum, width, truncate)
  local hlGroup = "Folded"
  local newVirtText = {}

  width = math.min(width, vim.o.colorcolumn)
  local targetWidth = width - 15
  local curWidth = 0

  -- Add current line text up until targetWidth
  for _, chunk in ipairs(virtText) do
    local chunkText = chunk[1]
    local chunkWidth = vim.fn.strdisplaywidth(chunkText)
    if targetWidth > curWidth + chunkWidth then
      table.insert(newVirtText, { chunkText, hlGroup })
      -- table.insert(newVirtText, chunk)
    else
      chunkText = truncate(chunkText, targetWidth - curWidth)
      table.insert(newVirtText, { chunkText, hlGroup })
      -- table.insert(newVirtText, { chunkText, chunk[2] })
      chunkWidth = vim.fn.strdisplaywidth(chunkText)
      break
    end
    curWidth = curWidth + chunkWidth
  end

  local specialChar = "―"
  local nSpecialChar = 6
  local nSpaces = width - curWidth - 9 - nSpecialChar

  local suffix = ("  %s %s %d"):format(
    (" "):rep(nSpaces),
    (specialChar):rep(nSpecialChar),
    endLnum - lnum
  )

  table.insert(newVirtText, { suffix, hlGroup })
  return newVirtText
end

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    require("ufo").setFoldVirtTextHandler(bufnr, fold_fmt_handler)
  end,
})

require("ufo").setup({
  open_fold_hl_timeout = 0,
  fold_virt_text_handler = fold_fmt_handler,
  provider_selector = function(_, _, _)
    return { "treesitter" }
  end,
})
