return {
  settings = { documentFormatting = false },
  on_attach = function(client, _)
    -- tsserver, stop messing with prettier da fuck!
    client.server_capabilities.document_formatting = false
  end,
}
