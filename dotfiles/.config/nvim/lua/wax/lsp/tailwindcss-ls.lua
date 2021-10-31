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
