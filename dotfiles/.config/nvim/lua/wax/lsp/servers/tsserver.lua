local mason_registry = require("mason-registry")
local vue_language_server_path = mason_registry
  .get_package("vue-language-server")
  :get_install_path() .. "/node_modules/@vue/language-server"

log.warn("vue_language_server_path", vue_language_server_path)

return {
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = vue_language_server_path,
        languages = { "vue" },
      },
    },
  },
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.server_capabilities.document_formatting = false
  end,
}
