return false

-- return {
--   -- filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },

--   -- https://github.com/yioneko/vtsls/issues/148
--   filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
--   -- on_attach = function(client, _)
--   --   client.server_capabilities.semanticTokensProvider = nil
--   -- end,
--   autoUseWorkspaceTsdk = true,
--   settings = {
--     typescript = {
--       tsserver = { log = "verbose" },
--       preferences = {
--         includePackageJsonAutoImports = "off",
--         autoImportFileExcludePatterns = { "**/components/**/*.vue" },
--       },
--     },
--     vtsls = {
--       experimental = { completion = { enableServerSideFuzzyMatch = true, entriesLimit = 5 } },
--       tsserver = {
--         globalPlugins = {
--           {
--             name = "@vue/typescript-plugin",
--             location = require("mason-registry")
--               .get_package("vue-language-server")
--               :get_install_path() .. "/node_modules/@vue/language-server",
--             languages = { "vue" },
--           },
--         },
--       },
--     },
--   },

--   --
-- }