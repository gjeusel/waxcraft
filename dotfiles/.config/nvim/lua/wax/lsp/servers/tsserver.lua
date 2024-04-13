-- return false -- better use vtsls (not sure in fact...)

return {
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = require("mason-registry").get_package("vue-language-server"):get_install_path()
          .. "/node_modules/@vue/language-server",
        languages = { "vue" },
      },
    },
  },
  settings = {
    -- https://code.visualstudio.com/docs/getstarted/settings#_default-settings
    -- // Specify glob patterns of files to exclude from auto imports.
    -- javascript.suggest.autoImports
    -- javascript = {
    --   suggest = { autoImports = false },
    --   -- preferences = { autoImportFileExcludePatterns = { "#build/components" } },
    -- },
    -- "javascript.preferences.autoImportFileExcludePatterns": [],
  },
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.server_capabilities.document_formatting = false
  end,
}
