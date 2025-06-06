vim.opt_local.foldminlines = 3
vim.opt_local.colorcolumn = "120" -- Show vertical bar at column 120

-- remove <:> from matchpairs as we use html tags
vim.o.matchpairs = "(:),{:},[:],':',\":\""


-- https://github.com/neovim/neovim/issues/32660
vim.g._ts_force_sync_parsing = true
