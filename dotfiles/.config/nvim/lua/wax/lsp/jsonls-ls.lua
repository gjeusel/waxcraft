-- Maybe add schemastore for classic json schemas
local json = {}
if is_module_available("schemastore") then
  json = {
    schemas = require("schemastore").json.schemas(),
    validate = { enable = true },
  }
end

return {
  settings = {
    json = json,
  },
}
