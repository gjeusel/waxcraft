-- return false

local preferences = {
  includePackageJsonAutoImports = "off",
  autoImportFileExcludePatterns = {
    "@vue/runtime-core",
    "@vue/runtime-dom",
    "@vue/reactivity",
    --
    "**/components/**/*.vue",
    "#imports",
    "**/*.ts", -- disable auto import from "#build/components", don't know why it works
  },
}

return {
  -- filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },

  -- https://github.com/yioneko/vtsls/issues/148
  filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
  on_attach = function(client, _)
    client.server_capabilities.semanticTokensProvider = nil
  end,
  autoUseWorkspaceTsdk = true,
  settings = {
    typescript = {
      -- tsserver = { log = "verbose" },
      preferences = preferences,
    },
    javascript = { preferences = preferences },
    vtsls = {
      experimental = { completion = { enableServerSideFuzzyMatch = true, entriesLimit = 5 } },
      -- tsserver = { globalPlugins = {} },
      tsserver = {
        globalPlugins = {
          {
            name = "@vue/typescript-plugin",
            location = require("mason-registry")
              .get_package("vue-language-server")
              :get_install_path() .. "/node_modules/@vue/language-server",
            languages = { "vue" },
            configNamespace = "typescript",
            enableForWorkspaceTypeScriptVersions = true,
          },
        },
      },
    },
  },
  -- before_init = function(params, config)
  --   local result = vim
  --     .system({ "npm", "query", "#vue" }, { cwd = params.workspaceFolders[1].name, text = true })
  --     :wait()
  --   if result.stdout ~= "[]" then
  --     local vuePluginConfig = {
  --       name = "@vue/typescript-plugin",
  --       location = require("mason-registry").get_package("vue-language-server"):get_install_path()
  --         .. "/node_modules/@vue/language-server",
  --       languages = { "vue" },
  --       configNamespace = "typescript",
  --       enableForWorkspaceTypeScriptVersions = true,
  --     }
  --     table.insert(config.settings.vtsls.tsserver.globalPlugins, vuePluginConfig)
  --   end
  -- end,
}
