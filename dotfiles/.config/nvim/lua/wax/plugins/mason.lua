require("mason").setup({
  log_level = vim.log.levels[waxopts.loglevel:upper()],
  max_concurrent_installers = 4,
  -- automatic_installation = true, -- auto install servers which are lspconfig setuped
  ensure_installed = waxopts.lsp.servers,
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
  },
})

vim.keymap.set({ "n" }, "<leader>fm", function()
  require("mason.ui").open()
end)
