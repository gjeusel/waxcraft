local grapple = require("grapple")
-- local scope_resolvers = require("grapple.scope_resolvers")
local scope = require("grapple.scope")

local loglevel = waxopts.loglevel
if loglevel == "trace" then
  loglevel = "debug"
end

local vim_session_scope = nil

-- scope_resolvers.workspace_fallback = scope.resolver(function()
--   if not vim_session_scope then
--     local path

--     local clients = vim.lsp.get_clients({ bufnr = 0 })
--     if #clients > 0 then
--       path = clients[1].config.root_dir
--     else
--       path = find_root_dir(vim.fn.getcwd()) or vim.fn.getcwd()
--     end

--     -- maybe add git infos from first opened buffer ?
--     -- {"git", "symbolic-ref", "--short", "HEAD" }

--     vim_session_scope = path
--   end

--   return vim_session_scope
-- end, { cache = { "FileType", "BufEnter", "FocusGained" } })

grapple.setup({
  ---@type "debug" | "info" | "warn" | "error"
  log_level = loglevel,

  scope = "git_branch", -- also try out "git_branch"

  ---Window options used for the popup menu
  win_opts = {
    relative = "editor",
    width = 80,
    height = 6,
    style = "minimal",
    focusable = false,
    border = "single",
  },
})

local function orderby_grapple_tags()
  local state = require("barbar.state")
  local render = require("barbar.ui.render")

  local tagged_files = vim.tbl_map(function(tag)
    return tag.path
  end, grapple.tags())

  local function index_of(tbl, val)
    for i, v in ipairs(tbl) do
      if v == val then
        return i
      end
    end
    return 1000
  end

  table.sort(state.buffers, function(left, right)
    if vim.api.nvim_buf_is_valid(left) and vim.api.nvim_buf_is_valid(right) then
      local left_name = vim.api.nvim_buf_get_name(left)
      local right_name = vim.api.nvim_buf_get_name(right)
      return index_of(tagged_files, left_name) < index_of(tagged_files, right_name)
    end
    return left < right
  end)
  log.warn("passing there")
  render.update()
end

vim.keymap.set("n", "<leader>tt", function()
  grapple.toggle()
end)
vim.keymap.set("n", "<leader>tl", function()
  grapple.toggle_tags()
end)

vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
  pattern = "*",
  callback = function(args)
    local filetype = vim.bo[args.buf].filetype
    if filetype == "grapple" then
      orderby_grapple_tags()
    end
  end,
})

local map_opt_idx = {
  ["¡"] = 1, -- option + 1
  ["™"] = 2, -- option + 2
  ["£"] = 3, -- option + 3
  ["¢"] = 4, -- option + 4
  ["∞"] = 5, -- option + 5
}
for keymap, grapple_key in pairs(map_opt_idx) do
  vim.keymap.set({ "n", "i", "x" }, keymap, function()
    if grapple.exists({ index = grapple_key }) then
      grapple.select({ index = grapple_key })
      orderby_grapple_tags()
    end
  end)
end
