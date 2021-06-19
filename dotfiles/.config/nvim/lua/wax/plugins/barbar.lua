vim.g.bufferline = {
  animation = false,
  icons = false,
  auto_hide = true,
  closable = false,
  clickable = false,
  maximum_padding = 1,
  icon_separator_active = '▎',
  icon_separator_inactive = "▎",
  no_name_title = "[ New buffer ]",
}

local opts = { noremap = true, nowait = true, silent = true }

keymap("in", "œ", "<cmd>BufferPrevious<cr>", opts) -- option + q
keymap("in", "∑", "<cmd>BufferNext<cr>", opts) -- option + w
keymap("in", "®", "<cmd>BufferClose<cr>", opts) -- option + r
keymap("in", "‰", "<cmd>BufferCloseAllButCurrent<cr>", opts) -- option + r
