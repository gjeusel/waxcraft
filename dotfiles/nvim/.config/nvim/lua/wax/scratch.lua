local M = {}

local default_ui_opts = {
  border = "rounded",
  winhl = "Normal",
  borderhl = "FloatBorder",
  height = 0.8,
  width = 0.8,
  x = 0.5,
  y = 0.5,
  winblend = 0,
}

local function _dimensions(opts)
  local cl = vim.o.columns
  local ln = vim.o.lines

  local width = math.ceil(cl * opts.width)
  local height = math.ceil(ln * opts.height - 4)

  local col = math.ceil((cl - width) * opts.x)
  local row = math.ceil((ln - height) * opts.y - 1)

  return {
    width = width,
    height = height,
    col = col,
    row = row,
  }
end

local function _resize(opts)
  local dim = _dimensions(opts)

  vim.api.nvim_win_set_config(M.win, {
    style = "minimal",
    relative = "editor",
    border = opts.border,
    height = dim.height,
    width = dim.width,
    col = dim.col,
    row = dim.row,
  })
end

function M.float_win(opts)
  opts = vim.tbl_extend("keep", opts or {}, default_ui_opts)

  local dim = _dimensions(opts)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    anchor = "NW",
    style = "minimal",
    width = dim.width,
    col = dim.col,
    row = dim.row,
    border = opts.border,
    height = dim.height,
    -- noautocmd = true,
  })

  -- Handle auto-resize
  vim.api.nvim_create_autocmd("VimResized", {
    callback = _resize,
    buffer = bufnr,
    desc = "Auto resize floating window",
  })

  -- Handle auto closing on WinLeave
  local close = function()
    vim.api.nvim_win_close(win, true)
    pcall(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end
  local aucmd_autoclose =
    vim.api.nvim_create_autocmd("WinLeave", { callback = close, buffer = bufnr })

  local open_vertical_split = function()
    vim.api.nvim_del_autocmd(aucmd_autoclose)
    vim.api.nvim_win_close(win, true)
    vim.cmd([[vsplit]])
    vim.api.nvim_win_set_buf(0, bufnr)
  end

  -- Add custom mappings
  local mappings = {
    n = {
      q = close,
      ["<ESC>"] = close,
      ["<C-v>"] = open_vertical_split,
    },
  }

  for mode, maps in pairs(mappings) do
    for k, v in pairs(maps) do
      if type(v) == "string" then
        vim.api.nvim_buf_set_keymap(bufnr, mode, k, v, { nowait = true })
      else
        vim.api.nvim_buf_set_keymap(bufnr, mode, k, "", { callback = v, nowait = true })
      end
    end
  end

  vim.api.nvim_win_set_option(win, "winhl", ("Normal:%s"):format(opts.winhl))
  vim.api.nvim_win_set_option(win, "winhl", ("FloatBorder:%s"):format(opts.borderhl))
  vim.api.nvim_win_set_option(win, "winblend", opts.winblend)

  vim.api.nvim_buf_set_option(bufnr, "filetype", "scratch")

  return { bufnr = bufnr, win = win }
end

return M
