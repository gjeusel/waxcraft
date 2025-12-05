require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<C-space>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = { ["dap-repl"] = true },
})

vim.g.SUPERMAVEN_DISABLED = 0

vim.keymap.set("n", "<C-x>", function()
  require("supermaven-nvim.api").toggle()
  if vim.g.SUPERMAVEN_DISABLED == 1 then
    print("supermaven disabled")
    vim.g.SUPERMAVEN_DISABLED = 0
  else
    print("supermaven enabled")
    vim.g.SUPERMAVEN_DISABLED = 1
  end
end, {
  silent = true,
  desc = "Toggle Supermaven",
})

-- Use custom highlight group for inline suggestions
local preview = require("supermaven-nvim.completion_preview")
preview.suggestion_group = "SupermavenSuggestion"
