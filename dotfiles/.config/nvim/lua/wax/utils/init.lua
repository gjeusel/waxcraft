require("wax.utils.os")
require("wax.utils.remaps")

if is_module_available("plenary.log") then
  level = os.getenv("WAX_LOG_LEVEL") or "info"
  log = require("plenary.log").new({ plugin = "wax", level = level, use_console = false })
else
  local mockfn = function(_) end
  log = setmetatable({}, { __index = mockfn })
end

-- lsp_symbol_map = {
--   Text = "",
--   Method = "",
--   Function = "",
--   Constructor = "",
--   Field = "ﰠ",
--   Variable = "[]",
--   Class = "",
--   Interface = "",
--   Module = "",
--   Property = "襁",
--   Unit = "塞",
--   Value = "",
--   Enum = "練",
--   Keyword = "",
--   Snippet = "",
--   Color = "",
--   File = "",
--   Reference = "",
--   Folder = "",
--   EnumMember = "",
--   Constant = "",
--   Struct = "פּ",
--   Event = "",
--   Operator = "",
--   TypeParameter = "",
-- }

waxopts = {
  python3 = "python3",
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

local function load_local_config(config_path)
  if vim.fn.filereadable(config_path) == 0 then
    return
  end

  local ok, err = pcall(vim.cmd, "luafile " .. config_path)
  if not ok then
    print("Invalid configuration", config_path)
    print(err)
    return
  end
end
load_local_config(vim.env.HOME .. "/.config/nvim/config.lua")
