vim.g.bufferline = {
  animation = false,
  icons = false,
  auto_hide = true,
  closable = false,
  clickable = false,
  maximum_padding = 1,
  icon_separator_active = "▎",
  icon_separator_inactive = "▎",
  -- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/13c2f1b8a4172408146439e7447c4c7519da4f53/lua/null-ls/formatting.lua#L30
  -- avoid scratch buffer display from null-ls
  no_name_title = "",
  exclude_name = { "" },
}

local opts = { noremap = true, nowait = true, silent = true }

keymap("in", "œ", "<cmd>BufferPrevious<cr>", opts) -- option + q
keymap("in", "∑", "<cmd>BufferNext<cr>", opts) -- option + w
keymap("in", "®", "<cmd>BufferClose<cr>", opts) -- option + r
keymap("in", "∂", "<cmd>BufferCloseAllButCurrent<cr>", opts) -- option + r
