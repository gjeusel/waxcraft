return {
  on_attach = function(client, _)
    -- formatting is done by prettier and eslint
    client.resolved_capabilities.document_formatting = false
  end,
}
