local default_options = {
  lsp = {
    servers = {},
    -- servers = {
    --   -- generic
    --   "efm",
    --   -- vim / bash / json / yaml
    --   "lua",
    --   "bash",
    --   "yaml",
    --   "json",
    --   -- frontend
    --   "typescript",
    --   "html",
    --   "svelte",
    --   "volar",
    --   -- "vue",
    --   "css",
    --   "tailwindcss",
    --   "graphql",
    --   -- backend
    --   "go",
    --   "rust",
    --   "pylsp",
    --   -- "pyright",
    --   "cmake",
    --   "rust",
    --   "go",
    --   -- infra
    --   "terraform",
    --   "dockerfile",
    -- },
  },
}

local options

local local_options = vim.env.HOME .. ".config/nvim/local.lua"
vim.cmd("runtime " .. local_options)

if is_module_available("local") then
  options = require("local")
else
  options = {}
end

waxopts = vim.tbl_deep_extend("force", default_options, options)

return waxopts
