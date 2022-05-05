return {
  -- disable formatting capabilities for yaml-ls as done by efm
  on_attach = function(client, _)
    -- formatting is done by efm:
    client.server_capabilities.document_formatting = false
  end,
  settings = {
    yaml = {
      editor = { tabSize = 2, formatOnType = false },
      validate = true,
      hover = true,
      completion = true,
      format = {
        enable = true,
        proseWrap = "Never",
        printWidth = 120,
      },
    },
  },
}
