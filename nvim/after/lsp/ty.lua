return {
  -- init_options = {
  --   logFile = vim.fn.stdpath("cache") .. "/ty.log",
  -- },
  -- Silence ty server panics (e.g. https://github.com/astral-sh/ty/issues/2401)
  on_error = function(_, _) end,
  handlers = {
    -- Disable the diagnostics of ty for now
    ["textDocument/publishDiagnostics"] = function() end,
    ["textDocument/diagnostic"] = function()
      return { kind = "full", items = {} }
    end,
    ["window/showMessage"] = function(_, result)
      if result and result.type == vim.lsp.protocol.MessageType.Error then
        return -- silence error notifications from ty
      end
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
