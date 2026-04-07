local log_level = "off"
if vim.tbl_contains({ "trace", "debug", "info" }, waxopts.loglevel) then
  log_level = waxopts.loglevel
end

require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<C-space>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = { ["dap-repl"] = true, jsonc = true, json = true },
  condition = function()
    return is_big_file(vim.api.nvim_buf_get_name(0))
  end,
  log_level = log_level,
})

-- Use custom highlight group for inline suggestions
local preview = require("supermaven-nvim.completion_preview")
preview.suggestion_group = "SupermavenSuggestion"
