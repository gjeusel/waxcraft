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
