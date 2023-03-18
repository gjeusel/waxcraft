--      _   _   __  __   __    __  _  ___  __   _   _  _  __ __
--     | | | | /  \ \ \_/ /   |  \| || __|/__\ | \ / || ||  V  |
--     | 'V' || /\ | > , <    | | ' || _|| \/ |`\ V /'| || \_/ |
--     !_/ \_!|_||_|/_/ \_\   |_|\__||___|\__/   \_/  |_||_| |_|
--
-- Inspired by:
-- - tjevries: https://github.com/tjdevries/config_manager/tree/master/xdg_config/nvim              ( the god )
-- - Connie2461: https://github.com/Conni2461/dotfiles/tree/master/.config/nvim                     ( the semi-god )
-- - ThePrimeagen: https://github.com/awesome-streamers/awesome-streamerrc/tree/master/ThePrimeagen ( the funny )
-- - ChristianChiarulli: https://github.com/ChristianChiarulli/LunarVim                             ( the ambitious )

require("wax.settings") -- vim.o
require("wax.userconfig") -- define user configs (waxopts)
require("wax.utils") -- utils with globals

require("wax.filetypes")
require("wax.keymaps")

require("wax.autocmds")

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
  custom_keys = false,
  checker = { enabled = false }, -- background plugin update checker
  change_detection = { enabled = true, notify = false },
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

safe_require("wax.folds")
