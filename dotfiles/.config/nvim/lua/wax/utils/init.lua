waxopts = {
  loglevel = "info",
  python3 = "python3",
  lsp = {
    loglevel = "warn",
    lspinstall = { loglevel = "warn" },
    servers = {},
    -- servers = {
    --   -- ________ generic ________
    --   "efm",
    --   "sumneko_lua",
    --   "bashls",
    --   "yamlls",
    --   "jsonls",
    --   "vimls",
    --   -- ________ frontend ________
    --   "tsserver",
    --   "html",
    --   -- "svelte",
    --   -- "vuels",
    --   "volar",
    --   "cssls",
    --   "tailwindcss",
    --   -- ________ backend ________
    --   "pylsp",
    --   -- ________ infra ________
    --   "terraformls",
    --   "dockerls",
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

require("wax.utils.os")
require("wax.utils.remaps")

if is_module_available("plenary.log") then
  log = require("plenary.log").new({
    plugin = "wax",
    level = waxopts.loglevel,
    use_console = false,
  })
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
