local root_pattern = require("lspconfig").util.root_pattern
local node = require("wax.lsp.nodejs-utils")

local install_script = node.global.bin.npm
  .. " install -g @volar/server typescript-vue-plugin typescript@4.3"
local uninstall_script = node.global.bin.npm .. " uninstall -g @volar/server typescript-vue-plugin"

local script_path = node.global.node_modules:joinpath("@volar/server/out/index.js"):absolute()
local tslib_path = node.global.node_modules:joinpath("typescript/lib/tsserverlibrary.js"):absolute()

require("lspinstall/servers")["volar"] = {
  default_config = {
    cmd = { node.global.bin.node, script_path, "--stdio" },
    root_dir = root_pattern("package.json", ".git", "vite.config.js", "vite.config.ts"),
    filetypes = { "vue" },
    init_options = {
      typescript = { serverPath = tslib_path },
      languageFeatures = {
        references = { enabledInTsScript = true },
        definition = true,
        typeDefinition = true,
        callHierarchy = true,
        hover = true,
        rename = true,
        signatureHelp = true,
        codeAction = true,
        completion = {
          defaultTagNameCase = "both",
          defaultAttrNameCase = "kebabCase",
          getDocumentNameCasesRequest = false,
          getDocumentSelectionRequest = false,
        },
        schemaRequestService = true,
        documentHighlight = true,
        documentLink = true,
        codeLens = { showReferencesNotification = false },
        semanticTokens = false, -- is making nvim lsp crash
        diagnostics = true,
      },
      documentFeatures = {
        selectionRange = true,
        foldingRange = true,
        linkedEditingRange = true,
        documentSymbol = true,
        documentColor = true,
        documentFormatting = false, -- prefer prettier + eslint
      },
    },
    settings = {
      volar = {
        codeLens = {
          references = false,
          pugTools = false,
          scriptSetupTools = false,
        },
      },
    },
  },
  install_script = install_script,
  uninstall_script = uninstall_script,
}

return {
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.resolved_capabilities.document_formatting = false
  end,
  on_new_config = function(config, new_workspace)
    local typescript_path = new_workspace .. "/node_modules/typescript/lib/tsserverlibrary.js"
    log.info("typescript path on new workspace", typescript_path)
    config.typescript = { serverPath = typescript_path }
    return config
  end,
}
