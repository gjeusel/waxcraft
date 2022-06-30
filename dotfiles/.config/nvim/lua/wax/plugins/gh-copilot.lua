if vim.fn.executable("node") ~= 1 then
  return
end

vim.g.copilot_enabled = false
-- vim.g.copilot_filetypes = {
--   ["*"] = false,
--   python = true,
--   -- frontend
--   javascript = true,
--   typescript = true,
--   vue = true,
-- }
vim.g.copilot_no_tab_map = true

require("copilot").setup({
  -- panel = { enabled = false },
  server_opts_overrides = {
    trace = waxopts.loglevel,
    -- name = "AI",
    -- settings = {
    --   advanced = {
    --     listCount = 10, -- #completions for panel
    --     inlineSuggestCount = 3, -- #completions for getCompletions
    --   },
    -- },
  },
  ft_disable = { "markdown", "terraform" },
})

-- -- https://vi.stackexchange.com/questions/21457/how-to-remap-autocomplete-on-controln-to-controlspace
-- vim.cmd([[
--   inoremap <C-@> <C-c>
--   map! <Nul> <c-space>
--   imap <silent><script><expr> <c-space> copilot#Accept("\<CR>")
--   imap <silent><script><expr> <c-j> copilot#Next()
--   imap <silent><script><expr> <c-k> copilot#Previous()
-- ]])

-- vim.cmd([[imap <expr> <Plug>(vimrc:dummy-copilot-tab) copilot#Accept("\<Tab>")]])

-- vim.keymap.set("i", "<c-space>", [[copilot#Accept("")]], {
--   noremap = true,
--   silent = true,
--   expr = true,
--   script = true,
--   desc = "copilot accept suggestion",
-- })
-- vim.keymap.set("i", "<c-j>", "copilot-next", {
--   noremap = true,
--   silent = true,
--   plug = true,
-- })
