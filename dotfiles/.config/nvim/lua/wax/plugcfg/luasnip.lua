local ls = require("luasnip")
local load_from_lua = require("luasnip.loaders.from_lua").lazy_load
local types = require("luasnip.util.types")

local symbol = "  ❬●❭"
local ext_opts = {
  [types.choiceNode] = {
    active = { virt_text = { { symbol, "GruvboxOrange" } } },
  },
  [types.insertNode] = {
    active = { virt_text = { { symbol, "GruvboxBlue" } } },
  },
}

-- Remove virtual text on InsertLeave
-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#ext_opts
local function cleanup_luasnip_extmarks()
  local node = ls.session.event_node
  if node then
    vim.api.nvim_buf_del_extmark(0, ls.session.ns_id, node.mark.id)
  end
end

vim.api.nvim_create_autocmd("InsertLeave", {
  callback = cleanup_luasnip_extmarks,
})

ls.config.set_config({
  history = true,
  -- Update more often, :h events for more info.
  updateevents = "TextChanged,TextChangedI",
  ext_opts = ext_opts,
  -- treesitter-hl has 100, use something higher (default is 200).
  ext_base_prio = 300,
  -- minimal increase in priority.
  ext_prio_increase = 1,
  enable_autosnippets = false,
})

ls.filetype_extend("vue", { "typescript", "html" })
ls.filetype_extend("svelte", { "typescript", "html" })
ls.filetype_extend("typescriptreact", { "typescript", "html" })
ls.filetype_extend("jinja.html", { "html" })

local snippets_path = require("wax.path").waxdir():join("snippets"):absolute()
load_from_lua({ paths = snippets_path })

-- mappings for navigating nodes
local kmapopts = { silent = true, nowait = true }
vim.keymap.set({ "i", "s" }, "<c-j>", function()
  if ls.expand_or_locally_jumpable() then
    ls.expand_or_jump()
  end
end, kmapopts)
vim.keymap.set({ "i", "s" }, "<c-k>", function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  end
end, kmapopts)

-- mappings for navigating node options
vim.keymap.set("i", "<c-l>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end, kmapopts)
vim.keymap.set("i", "<c-h>", function()
  if ls.choice_active() then
    ls.change_choice(-1)
  end
end, kmapopts)

local M = {}

function M.reload()
  load_from_lua({ paths = snippets_path })
end

return M
