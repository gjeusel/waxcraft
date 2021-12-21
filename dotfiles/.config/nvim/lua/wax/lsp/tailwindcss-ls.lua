local filetypes = {
  "html",
  "css",
  "less",
  "postcss",
  "sass",
  "scss",
  "stylus",
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "svelte",
}

return {
  on_attach = function(client, _)
    -- Disable symbols for tailwindcss
    client.resolved_capabilities.document_symbol = false
    client.resolved_capabilities.workspace_symbol = false
  end,
  init_options = {
    userLanguages = {
      eelixir = "html-eex",
      eruby = "erb",
    },
  },
  filtypes = filetypes,
  settings = {
    tailwindCSS = {
      emmetCompletions = true,
    },
  },
}
