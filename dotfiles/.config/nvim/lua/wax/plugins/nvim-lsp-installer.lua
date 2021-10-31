local lsp_installer = require("nvim-lsp-installer")

lsp_installer.settings({
  log_level = vim.log.levels.DEBUG,
  max_concurrent_installers = 4,
  -- -- The directory in which to install all servers.
  -- install_root_dir = path.concat({ vim.fn.stdpath("data"), "lsp_servers" }),
})
