local python_utils = require("wax.lsp.python-utils")

-- documentFormattingProvider
-- documentRangeFormattingProvider
-- callHierarchyProvider
-- codeActionProvider
-- codeLensProvider = {
--   resolveProvider = false
-- },
-- completionProvider = {
--   resolveProvider = true,
--   triggerCharacters = { "." }
-- },
-- declarationProvider
-- definitionProvider
-- documentHighlightProvider
-- documentSymbolProvider
-- executeCommandProvider
-- hoverProvider
-- referencesProvider
-- renameProvider
-- signatureHelpProvider
-- typeDefinitionProvider
-- workspaceSymbolProvider

return {
  on_attach = function(client, _)
    -- disable capabilities that are better handled by pylsp
    client.server_capabilities.renameProvider = false -- rope is ok
    client.server_capabilities.hoverProvider = false -- pylsp includes also docstrings
    client.server_capabilities.signatureHelpProvider = false -- pyright typing of signature is weird
    client.server_capabilities.definitionProvider = false -- pyright does not follow imports correctly
    client.server_capabilities.referencesProvider = false -- pylsp does it
    -- client.server_capabilities.completionProvider = false -- missing when dep is untyped
    client.server_capabilities.completionProvider = {
      resolveProvider = true,
      triggerCharacters = { "." },
    }
  end,
  settings = {
    python = {
      -- https://github.com/microsoft/pyright/blob/main/docs/settings.md
      disableOrganizeImports = true,
      analysis = {
        -- diagnosticMode = "workspace",
        -- autoSearchPaths = true,
        -- typeCheckingMode = "basic",

        -- All disabled, keep only auto importing
        -- autoImportCompletions = true,  -- only thing I use pyright for
        diagnosticMode = "openFilesOnly",
        autoSearchPaths = false,
        typeCheckingMode = "off",
        diagnosticSeverityOverrides = {
          -- reportUnusedVariable = "error",
        },
      },
    },
  },
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace)
    local new_workspace_name = to_workspace_name(new_workspace)

    if python_path == "python" then
      local msg = "LSP python (pyright) - keeping previous python path '%s' for new_root_dir '%s'"
      log.debug(msg:format(config.cmd[1], new_workspace))
      return config
    else
      local msg = "LSP python (pyright) - '%s' using path %s"
      log.info(msg:format(new_workspace_name, python_path))

      config.settings.python.pythonPath = python_path
      return config
    end
  end,
}
