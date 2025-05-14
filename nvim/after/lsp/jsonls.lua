-- Maybe add schemastore for classic json schemas
local json = {}
if is_module_available("schemastore") then
  json = {
    schemas = require("schemastore").json.schemas(),
    validate = { enable = true },
  }
end

return {
  -- cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  init_options = { provideFormatter = false }, -- better done by jq
  settings = {
    json = json,
    -- configure = {
    --   allowComments = true,
    -- },
  },
}
