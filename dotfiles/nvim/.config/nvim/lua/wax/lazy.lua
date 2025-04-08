-- Install package manager - https://github.com/folke/lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({ import = "wax.plugins" }, {
  dev = { path = "~/src" },
  defaults = {
    lazy = true,
    version = false, -- always use the latest git commit
  },
  install = { colorscheme = { "gruvbox" } },
  custom_keys = false,
  checker = { enabled = false }, -- background plugin update checker
  change_detection = { enabled = true, notify = false },
  ui = {
    border = "rounded",
    icons = {
      cmd = "❯ ",
      config = "",
      event = "",
      ft = " ",
      init = " ",
      import = " ",
      keys = " ",
      lazy = "󰒲 ",
      loaded = "●",
      not_loaded = "○",
      plugin = " ",
      runtime = " ",
      source = " ",
      start = "➤",
      task = "✔ ",
      list = {
        "●",
        "➜",
        "★",
        "‒",
      },
    },
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "tohtml",
        "tutor",
        "gzip",
        "zip",
        "zipPlugin",
        "tar",
        "tarPlugin",
        "getscript",
        "getscriptPlugin",
        "vimball",
        "vimballPlugin",
        "2html_plugin",
        "logipat",
        "rrhelper",
        "spellfile_plugin",
        "fzf",
        "matchit",
        "matchparen",
      },
    },
  },
})

-- vim.keymap.set("n", "<leader>fp", function()
--   require("lazy").profile()
-- end)
