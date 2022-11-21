local ls = require("luasnip")
local load_from_lua = require("luasnip.loaders.from_lua").load

-- Every unspecified option will be set to the default.
ls.config.set_config({
  history = true,
  -- Update more often, :h events for more info.
  updateevents = "TextChanged,TextChangedI",
  -- ext_opts = {
  --   [types.choiceNode] = {
  --     active = {
  --       virt_text = { { "●", "GruvboxOrange" } },
  --     },
  --   },
  --   [types.insertNode] = {
  --     active = {
  --       virt_text = { { "●", "GruvboxBlue" } },
  --     },
  --   },
  -- },
  -- treesitter-hl has 100, use something higher (default is 200).
  ext_base_prio = 300,
  -- minimal increase in priority.
  ext_prio_increase = 1,
  enable_autosnippets = false,
})

local snippets_path = vim.env.waxCraft_PATH .. "/dotfiles/.config/nvim/lua/wax/plugins/snippets"

load_from_lua({ paths = snippets_path })

ls.filetype_extend("vue", { "typescript" })
ls.filetype_extend("typescriptreact", { "typescript" })

local function silent_cmd(cmd)
  return vim.api.nvim_exec(cmd, false)
end

-- mappings for navigating nodes
local kmapopts = { silent = true, nowait = true }
vim.keymap.set({ "i", "s" }, "<c-j>", function()
  if ls.expand_or_jumpable() then
    ls.expand_or_jump()
  else
    silent_cmd("TmuxNavigateDown")
  end
end, kmapopts)
vim.keymap.set({ "i", "s" }, "<c-k>", function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  else
    silent_cmd("TmuxNavigateUp")
  end
end, kmapopts)

-- mappings for navigating node options
vim.keymap.set("i", "<c-l>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  else
    silent_cmd("TmuxNavigateRight")
  end
end, kmapopts)
vim.keymap.set("i", "<c-h>", function()
  if ls.choice_active() then
    ls.change_choice(-1)
  else
    silent_cmd("TmuxNavigateLeft")
  end
end, kmapopts)

local M = {}

function M.reload()
  load_from_lua({ paths = snippets_path })
end

return M
