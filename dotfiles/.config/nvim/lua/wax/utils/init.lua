require("wax.utils.os")
require("wax.utils.remaps")

if is_module_available("plenary.log") then
  level = os.getenv("WAX_DEBUG") or "info"
  log = require("plenary.log").new({ plugin = "wax", level = level, use_console = false })
else
  local mockfn = function(_) end
  log = setmetatable({}, { __index = mockfn })
end
