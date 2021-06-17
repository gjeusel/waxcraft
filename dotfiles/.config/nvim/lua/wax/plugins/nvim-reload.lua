local reload = require('nvim-reload')

-- If you use Neovim's built-in plugin system
-- Or a plugin manager that uses it (eg: packer.nvim)
local plugin_dirs = vim.fn.stdpath('data') .. '/site/pack/*/start/*'

reload.vim_reload_dirs = {
    vim.fn.stdpath('config'),
    plugin_dirs
}

reload.lua_reload_dirs = {
    vim.fn.stdpath('config'),
    -- Note: the line below may cause issues reloading your config
    plugin_dirs
}

-- reload.files_reload_external = {
--     vim.fn.stdpath('config') .. '/myfile.vim'
-- }

reload.modules_reload_external = { 'packer' }

-- reload.post_reload_hook = function()
--     require('feline').reset_highlights()
-- end

-- nmap('<F12>', '<cmd>Reload<cr>')  -- failing
nmap('<F12>', '<cmd>luafile ~/.config/nvim/init.lua<cr>')
-- nmap('<F12>', '<cmd>lua require("plenary.reload").reload_module("wax")<cr>')
