local yamlls_settings = require("wax.lsp.yamlls")

return {
  settings = {
    ["helm-ls"] = {
      yamlls = {
        enabled = true,
        config = vim.tbl_deep_extend("force", yamlls_settings.settings.yaml, {
          schemas = {
            ["https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/_definitions.json"] = "templates/**",
          },
        }),
      },
    },
  },
}
