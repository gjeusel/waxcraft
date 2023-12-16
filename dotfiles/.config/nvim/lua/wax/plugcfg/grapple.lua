local grapple = require("grapple")
local scope_resolvers = require("grapple.scope_resolvers")
local scope = require("grapple.scope")

local loglevel = waxopts.loglevel
if loglevel == "trace" then
  loglevel = "debug"
end

local vim_session_scope = nil

scope_resolvers.workspace_fallback = scope.resolver(function()
  if not vim_session_scope then
    local path

    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients > 0 then
      path = clients[1].config.root_dir
    else
      path = find_root_dir(vim.fn.getcwd()) or vim.fn.getcwd()
    end

    vim_session_scope = path
  end

  return vim_session_scope
end, { cache = { "FileType", "BufEnter", "FocusGained" } })

grapple.setup({
  ---@type "debug" | "info" | "warn" | "error"
  log_level = loglevel,

  ---The scope used when creating, selecting, and deleting tags
  -- scope = "git",
  -- scope = "lsp",
  scope = scope.fallback({ "workspace_fallback", "static" }),

  ---Window options used for the popup menu
  popup_options = {
    relative = "editor",
    width = 80,
    height = 6,
    style = "minimal",
    focusable = false,
    border = "single",
  },
})

vim.keymap.set("n", "<leader>tt", grapple.toggle)
vim.keymap.set("n", "<leader>tl", grapple.popup_tags)
vim.keymap.set("n", "<leader>tk", grapple.popup_scopes)

local map_opt_idx = {
  ["¡"] = 1, -- option + 1
  ["™"] = 2, -- option + 2
  ["£"] = 3, -- option + 3
  ["¢"] = 4, -- option + 4
  ["∞"] = 5, -- option + 5
}
for keymap, grapple_key in pairs(map_opt_idx) do
  vim.keymap.set({ "n", "i", "x" }, keymap, function()
    if grapple.exists({ key = grapple_key }) then
      grapple.select({ key = grapple_key })
    end
  end)
end

local function orderby_grapple_tags()
  local bufline_state = require("bufferline.state")
  local render = require("bufferline.render")
  local grapple_state = require("grapple.state")
  local grapple_settings = require("grapple.settings")

  local actual_scope = grapple_state.ensure_loaded(grapple_settings.scope)
  local state_scope = grapple_state.scope(actual_scope)

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

vim.api.nvim_create_autocmd({ "BufEnter", "BufModifiedSet" }, {
  pattern = "*",
  callback = orderby_grapple_tags,
})
