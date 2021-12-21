return {
  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#volar
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.resolved_capabilities.document_formatting = false
  end,
  docs = {
    package_json = "https://github.com/johnsoncodehk/volar/blob/b71700d1ce0ff8be7fda857b022530e02a58f2bd/extensions/vscode-vue-language-features/package.json",
  },
  settings = {
    volar = {
      lowPowerMode = false,
      autoCompleteRefs = true,
      completion = {
        -- preferredTagNameCase = "pascal",
        -- preferredAttrNameCase = "kebab",
        autoImportComponent = false,
      },
      style = { defaultLanguage = "postcss" },
      tsPlugin = true,
      tsPluginStatus = false,
    },
  },
  init_options = {
    documentFeatures = { documentSymbol = true },
    languageFeatures = {
      callHierarchy = true,
      -- completion = {
      --   defaultAttrNameCase = "kebabCase",
      --   defaultTagNameCase = "kebabCase",
      --   getDocumentNameCasesRequest = true,
      --   getDocumentSelectionRequest = true,
      -- },
      definition = true,
      diagnostics = true,
      hover = true,
      references = true,
      rename = true,
      renameFileRefactoring = true,
      signatureHelp = true,
      typeDefinition = true,
    },
  },
}
