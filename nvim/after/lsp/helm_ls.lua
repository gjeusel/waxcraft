local yamlls_settings = require("wax.lsp.yamlls")

return {
  settings = {
    ["helm-ls"] = {
      yamlls = {
        enabled = true,
        config = vim.tbl_extend("keep", {
          schemas = { kubernetes = "templates/**" },
        }, yamlls_settings.settings.yaml),
      },
    },
  },
}
