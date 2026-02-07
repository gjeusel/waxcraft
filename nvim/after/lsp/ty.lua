return {
  on_attach = function(client, bufnr)
    client.server_capabilities.documentHighlightProvider = false
    client.server_capabilities.semanticTokensProvider = nil
    -- Disable semantic tokens for this buffer/client
    vim.lsp.semantic_tokens.enable(false, { client_id = client.id })
  end,
  -- init_options = {
  --   logFile = vim.fn.stdpath("cache") .. "/ty.log",
  -- },
  handlers = {
    -- Disable the diagnostics of ty for now
    ["textDocument/publishDiagnostics"] = function() end,
    ["textDocument/diagnostic"] = function()
      return { kind = "full", items = {} }
    end,
  },
  settings = {
    ty = {
      experimental = {
        rename = true, -- https://docs.astral.sh/ty/reference/editor-settings/#rename
        autoImport = true,
      },
    },
  },
}
