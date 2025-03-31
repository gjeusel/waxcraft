-- return false

local suggest = {
  autoImports = false,
  classMemberSnippets = { enabled = false },
  objectLiteralMethodSnippets = { enabled = false },
}

local preferences = {
  quoteStyle = "double",
  includePackageJsonAutoImports = "off",
  -- autoImportFileExcludePatterns = {
  --   "@vue/runtime-core",
  --   "@vue/runtime-dom",
  --   "@vue/reactivity",
  --   --
  --   "#imports",
  --   "**/components/**/*.vue",
  --   "**/*.ts", -- disable auto import from "#build/components", don't know why it works
  -- },
}

return {
  -- filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },

  -- https://github.com/yioneko/vtsls/issues/148
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  on_attach = function(client, _)
    client.server_capabilities.semanticTokensProvider = nil
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false

    -- improve file renaming:
    -- https://github.com/vuejs/language-tools/issues/4500
    client.server_capabilities.workspace = {
      didChangeWatchedFiles = { dynamicRegistration = true },
      fileOperations = {
        didRename = {
          filters = {
            {
              pattern = {
                glob = "**/*.{ts,cts,mts,tsx,js,cjs,mjs,jsx,vue}",
              },
            },
          },
        },
      },
    }
  end,
  autoUseWorkspaceTsdk = true,
  settings = {
    -- https://github.com/yioneko/vtsls/blob/6adfb5d3889ad4b82c5e238446b27ae3ee1e3767/packages/service/configuration.schema.json#L808
    typescript = {
      preferGoToSourceDefinition = true,
      workspaceSymbols = { scope = "currentProject" },
      updateImportsOnFileMove = { enabled = "always" },
      preferences = vim.tbl_extend("force", { preferTypeOnlyAutoImports = true }, preferences),
      suggest = suggest,
      tsserver = {
        useSyntaxServer = "never",
        maxTsServerMemory = 3840,
        -- log = "verbose",
      },
    },
    javascript = {
      preferGoToSourceDefinition = true,
      preferences = preferences,
      suggest = suggest,
    },
    vtsls = {
      experimental = { completion = { enableServerSideFuzzyMatch = true, entriesLimit = 5 } },
      -- tsserver = { globalPlugins = {} },
      tsserver = {
        globalPlugins = {
          -- {
          --   name = "@vue/typescript-plugin",
          --   location = require("mason-registry")
          --     .get_package("vue-language-server")
          --     :get_install_path() .. "/node_modules/@vue/language-server",
          --   languages = { "vue" },
          --   configNamespace = "typescript",
          --   enableForWorkspaceTypeScriptVersions = true,
          -- },
        },
      },
    },
  },
}
