return {
  on_attach = function(client, _)
    client.server_capabilities.documentHighlightProvider = false
    client.server_capabilities.semanticTokensProvider = false

    -- For now, disable diagnostics as not ready to adopt
    client.server_capabilities.diagnosticProvider = false

    -- Silence LSP error notifications for ty server
    local original_notify = vim.notify
    vim.notify = function(msg, level, opts)
      if msg and msg:match("LSP%[ty%]") then
        return -- Silently ignore ty LSP notifications
      end
      original_notify(msg, level, opts)
    end
  end,
  -- init_options = {
  --   logFile = vim.fn.stdpath("cache") .. "/ty.log",
  -- },
  settings = {
    ty = {
      -- https://docs.astral.sh/ty/reference/editor-settings/#rename
      experimental = {
        rename = true,
      },
    },
  },
}
