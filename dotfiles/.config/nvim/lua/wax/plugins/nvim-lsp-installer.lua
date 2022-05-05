require("nvim-lsp-installer").setup({
  log_level = vim.log.levels[waxopts.lsp.lspinstall.loglevel:upper()],
  max_concurrent_installers = 4,
  -- -- The directory in which to install all servers.
  -- install_root_dir = path.concat({ vim.fn.stdpath("data"), "lsp_servers" }),
})
