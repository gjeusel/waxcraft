return {
  on_attach = function(client, _)
    client.server_capabilities.documentHighlightProvider = false
    client.server_capabilities.semanticTokensProvider = false

    -- For now, disable diagnostics as not ready to adopt
    client.server_capabilities.diagnosticProvider = false
  end,
  -- init_options = {
  --   logFile = vim.fn.stdpath("cache") .. "/ty.log",
  -- },
  --
  settings = {
    ty = {
      -- https://docs.astral.sh/ty/reference/editor-settings/#rename
      experimental = {
        rename = true,
        autoImport = true,
      },
    },
  },
}
