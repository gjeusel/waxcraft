return {
  settings = { documentFormatting = false },
  on_attach = function(client, _)
    client.resolved_capabilities.document_formatting = false
  end,
  init_options = {
    config = {
      vetur = {
        useWorkspaceDependencies = false,
        validation = {
          template = true,
          style = true,
          script = true,
        },
        completion = {
          autoImport = false,
          useScaffoldSnippets = false,
          tagCasing = "kebab",
        },
      },
    },
  },
}
