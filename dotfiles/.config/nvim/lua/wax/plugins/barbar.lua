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

local kmap = vim.keymap.set
local opts = { nowait = true, silent = true }
kmap({ "n", "i" }, "œ", "<cmd>BufferPrevious<cr>", opts) -- option + q
kmap({ "n", "i" }, "∑", "<cmd>BufferNext<cr>", opts) -- option + w
kmap({ "n", "i" }, "®", "<cmd>BufferClose<cr>", opts) -- option + r
kmap({ "n" }, "©", "<cmd>BufferCloseAllButCurrent<cr>", opts) -- option + g

local bufline_state = require("bufferline.state")
local render = require("bufferline.render")

local grapple_state = require("grapple.state")
local grapple_settings = require("grapple.settings")

local function orderby_grapple_tags()
  local scope = grapple_state.ensure_loaded(grapple_settings.scope)
  local state_scope = grapple_state.scope(scope)

  if vim.tbl_count(state_scope) == 0 then
    return
  end

  local tagged_files = {}
  for i, e in ipairs(state_scope) do
    tagged_files[e.file_path] = i
  end

  local default_rank = 1000
  table.sort(bufline_state.buffers, function(left, right)
    local left_name = vim.api.nvim_buf_get_name(left)
    local right_name = vim.api.nvim_buf_get_name(right)
    local left_rank = vim.tbl_get(tagged_files, left_name) or default_rank + left
    local right_rank = vim.tbl_get(tagged_files, right_name) or default_rank + right
    -- log.warn("\nleft_name=", left_name, "left_rank=", left_rank)
    -- log.warn("\nright_name=", right_name, "right_rank=", right_rank)
    return left_rank < right_rank
  end)
  render.update()
end

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = orderby_grapple_tags,
})
