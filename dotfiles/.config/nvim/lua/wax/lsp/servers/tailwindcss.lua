local filetypes = {
  -- html
  "aspnetcorerazor",
  "astro",
  "astro-markdown",
  "blade",
  "django-html",
  "htmldjango",
  "jinja.html",
  "edge",
  "eelixir", -- vim ft
  "elixir",
  "ejs",
  "erb",
  "eruby", -- vim ft
  "gohtml",
  "haml",
  "handlebars",
  "hbs",
  "html",
  -- 'HTML (Eex)',
  -- 'HTML (EEx)',
  "html-eex",
  "heex",
  "jade",
  "leaf",
  "liquid",
  "markdown",
  "mdx",
  "mustache",
  "njk",
  "nunjucks",
  "php",
  "razor",
  "slim",
  "twig",
  -- css
  "css",
  "less",
  "postcss",
  "sass",
  "scss",
  "stylus",
  "sugarss",
  -- js
  "javascript",
  "javascriptreact",
  "reason",
  "rescript",
  "typescript",
  "typescriptreact",
  -- mixed
  "vue",
  "svelte",
}

return {
  init_options = {
    userLanguages = {
      ["jinja.html"] = "html",
    },
  },
  filetypes = filetypes,
  settings = {
    tailwindCSS = {
      validate = true,
      emmetCompletions = true,
      colorDecorators = false, -- unsupported on nvim
      includeLanguages = {
        ["jinja.html"] = "html",
      },
      -- experimental = {
        --   configFile = "../../../scripts/weasytail/tailwind.config.js",
      -- },
    },
  },
}
