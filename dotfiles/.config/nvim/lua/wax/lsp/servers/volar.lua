-- https://github.com/vuejs/language-tools/blob/20d713b/packages/shared/src/types.ts
local init_options = {
  languageFeatures = {
    references = true,
    implementation = true,
    definition = true,
    typeDefinition = true,
    callHierarchy = true,
    hover = true,
    rename = true,
    renameFileRefactoring = true,
    signatureHelp = true,
    documentHighlight = false,
    documentLink = false,
    workspaceSymbol = true,
    codeLens = false,
    semanticTokens = false,
    codeAction = true,
    inlayHints = false,
    diagnostics = true,
    schemaRequestService = false,
  },
  documentFeatures = {
    selectionRange = false,
    foldingRange = false,
    linkedEditingRange = false,
    documentSymbol = true,
    documentColor = false,
    documentFormatting = false,
  },
}

return {
  -- enable takeover
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#volar
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  docs = {
    package_json = "https://github.com/johnsoncodehk/volar/blob/5496c1ecc0ae6207d6fa7da745f047c44c32db81/extensions/vscode-vue-language-features/package.json",
  },
  settings = {
    -- typescript = {
    --   suggest = { autoImports = false },
    -- },
    volar = {
      autoCompleteRefs = true,
      codelens = {
        references = false,
        pugTools = false,
      },
      icon = { preview = false },
      doctor = { statusBarItem = false },
      -- format = {},
      completion = {
        preferredTagNameCase = "auto-pascal",
        preferredAttrNameCase = "auto-pascal",
        autoImportComponent = false,
      },
      -- diagnostics = { delay = 200 },
    },
  },
  init_options = init_options,
}
