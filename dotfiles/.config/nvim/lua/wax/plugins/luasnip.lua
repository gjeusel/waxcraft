local ls = require("luasnip")
-- local types = require("luasnip.util.types")

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

ls.add_snippets(nil, require("wax.plugins.snippets"))

ls.filetype_extend("vue", { "typescript" })
ls.filetype_extend("typescriptreact", { "typescript" })

-- vim.cmd([[
--   inoremap <silent> <c-j> <cmd>lua require('luasnip').jump(1)<CR>
--   inoremap <silent> <c-k> <cmd>lua require('luasnip').jump(-1)<CR>
-- ]])

-- mappings for navigating nodes
vim.keymap.set({ "i", "s" }, "<c-j>", function()
  if ls.expand_or_jumpable() then
    ls.expand_or_jump()
  end
end, {
  silent = true,
})
vim.keymap.set({ "i", "s" }, "<c-k>", function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  end
end, {
  silent = true,
})

-- mappings for navigating node options
vim.keymap.set("i", "<c-l>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end)
vim.keymap.set("i", "<c-h>", function()
  if ls.choice_active() then
    ls.change_choice(-1)
  end
end)

-- -- shorcut to source my luasnips file again, which will reload my snippets
-- vim.keymap.set(
--   "n",
--   "<leader><leader>s",
--   -- "<cmd>source "
--   --   .. vim.env.waxCraft_PATH
--   --   .. "/dotfiles/.config/nvim/lua/wax/plugins/luasnip.lua<CR>"
-- )

-- From Wiki: Popup window on choiceNode

local M = {}

local current_nsid = vim.api.nvim_create_namespace("LuaSnipChoiceListSelections")
local current_win = nil

local function window_for_choiceNode(choiceNode)
  local buf = vim.api.nvim_create_buf(false, true)
  local buf_text = {}
  local row_selection = 0
  local row_offset = 0
  local text
  for _, node in ipairs(choiceNode.choices) do
    text = node:get_docstring()
    -- find one that is currently showing
    if node == choiceNode.active_choice then
      -- current line is starter from buffer list which is length usually
      row_selection = #buf_text
      -- finding how many lines total within a choice selection
      row_offset = #text
    end
    vim.list_extend(buf_text, text)
  end

  vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, buf_text)
  local w, h = vim.lsp.util._make_floating_popup_size(buf_text)

  -- adding highlight so we can see which one is been selected.
  local extmark = vim.api.nvim_buf_set_extmark(
    buf,
    current_nsid,
    row_selection,
    0,
    { hl_group = "incsearch", end_line = row_selection + row_offset }
  )

  -- shows window at a beginning of choiceNode.
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "win",
    width = w,
    height = h,
    bufpos = choiceNode.mark:pos_begin_end(),
    style = "minimal",
    border = "rounded",
  })

  -- return with 3 main important so we can use them again
  return { win_id = win, extmark = extmark, buf = buf }
end

M.choice_popup = function(choiceNode)
  -- build stack for nested choiceNodes.
  if current_win then
    vim.api.nvim_win_close(current_win.win_id, true)
    vim.api.nvim_buf_del_extmark(current_win.buf, current_nsid, current_win.extmark)
  end
  local create_win = window_for_choiceNode(choiceNode)
  current_win = {
    win_id = create_win.win_id,
    prev = current_win,
    node = choiceNode,
    extmark = create_win.extmark,
    buf = create_win.buf,
  }
end

M.update_choice_popup = function(choiceNode)
  vim.api.nvim_win_close(current_win.win_id, true)
  vim.api.nvim_buf_del_extmark(current_win.buf, current_nsid, current_win.extmark)
  local create_win = window_for_choiceNode(choiceNode)
  current_win.win_id = create_win.win_id
  current_win.extmark = create_win.extmark
  current_win.buf = create_win.buf
end

M.choice_popup_close = function()
  vim.api.nvim_win_close(current_win.win_id, true)
  vim.api.nvim_buf_del_extmark(current_win.buf, current_nsid, current_win.extmark)
  -- now we are checking if we still have previous choice we were in after exit nested choice
  current_win = current_win.prev
  if current_win then
    -- reopen window further down in the stack.
    local create_win = window_for_choiceNode(current_win.node)
    current_win.win_id = create_win.win_id
    current_win.extmark = create_win.extmark
    current_win.buf = create_win.buf
  end
end

-- vim.cmd([[
-- augroup choice_popup
-- au!
-- au User LuasnipChoiceNodeEnter lua require("wax.plugins.luasnip").choice_popup(require("luasnip").session.event_node)
-- au User LuasnipChoiceNodeLeave lua require("wax.plugins.luasnip").choice_popup_close()
-- au User LuasnipChangeChoice lua require("wax.plugins.luasnip").update_choice_popup(require("luasnip").session.event_node)
-- augroup END
-- ]])

return M
