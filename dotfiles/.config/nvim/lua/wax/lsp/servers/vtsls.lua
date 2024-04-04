return {
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },

  -- -- https://github.com/yioneko/vtsls/issues/148
  -- filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  -- settings = {
  --   vtsls = {
  --     tsserver = {
  --       globalPlugins = {
  --         {
  --           name = "@vue/typescript-plugin",
  --           location = require("mason-registry")
  --             .get_package("vue-language-server")
  --             :get_install_path() .. "/node_modules/@vue/language-server",
  --           languages = { "vue" },
  --         },
  --       },
  --     },
  --   },
  -- },
}
