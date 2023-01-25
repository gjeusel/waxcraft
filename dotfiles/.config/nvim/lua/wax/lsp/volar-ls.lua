local tsdk = vim.env.HOME .. "/.volta/tools/shared/typescript/lib"

local init_options = {
  petiteVue = { processHtmlFile = false },
  vitePress = { processMdFile = false },
  typescript = { tsdk = tsdk },
  -- serverMode = 0, --
  ignoreTriggerCharacters = "",
  -- textDocumentSync = 2,
}

return {
  -- enable takeover
  -- filetypes = { "typescript", "vue" },

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
    volar = {
      autoCompleteRefs = true,
      codelens = {},
      -- format = {},
      completion = {
        preferredTagNameCase = "auto-pascal",
        preferredAttrNameCase = "auto-pascal",
        autoImportComponent = false,
      },
      diagnostics = { delay = 200 },
    },
  },
  init_options = init_options,
  -- on_new_config = function(new_config, new_workspace)
  --   -- TODO: case of monorepo, use maybe ts path of lower node_modules relative to file
  --   -- new_config.init_options.typescript.tsdk = tsPath
  -- end,
}
