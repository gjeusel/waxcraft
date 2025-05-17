local state = {}

local function setup()
  vim.keymap.set("n", "<C-x>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local is_active = vim.tbl_get(state, bufnr)
    if is_active then
      print("supermaven disabled")
    else
      print("supermaven on")
      local api = require("supermaven-nvim.api")
      if not api.is_running() then
        api.start()
      end
    end
    state[bufnr] = not is_active
  end, { desc = "SuperMaven Toggle" })

  require("supermaven-nvim").setup({
    keymaps = {
      accept_suggestion = "<C-space>",
      clear_suggestion = "<C-]>",
      accept_word = "<C-j>",
    },
    condition = function() -- if return true, disable supermaven
      local enabled_ft = { "lua", "javascript", "typescript", "vue", "tsx", "html" }

      local bufnr = vim.api.nvim_get_current_buf()
      local is_active = vim.tbl_get(state, bufnr)
      if is_active == nil then
        is_active = vim.tbl_contains(enabled_ft, vim.bo.filetype)
        state[bufnr] = is_active
      end
      log.warn(state)
      return not is_active
    end,
  })
end

local M = {
  setup = setup,
  state = state,
  is_active_for_buffer = function(bufnr)
    return vim.tbl_get(state, bufnr or vim.api.nvim_get_current_buf())
  end,
}

return M
