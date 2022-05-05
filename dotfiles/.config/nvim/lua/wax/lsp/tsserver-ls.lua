return {
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.server_capabilities.document_formatting = false
  end,
}
