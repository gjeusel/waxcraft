local root_pattern = require("lspconfig").util.root_pattern
local node = require("wax.lsp.nodejs-utils")

local install_script = node.global.bin.npm .. " install -g @tailwindcss/language-server"
local uninstall_script = node.global.bin.npm .. " uninstall -g @tailwindcss/language-server"

local filetypes = {
  "aspnetcorerazor",
  "astro",
  "astro-markdown",
  "blade",
  "django-html",
  "edge",
  "eelixir",
  "ejs",
  "erb",
  "eruby",
  "gohtml",
  "haml",
  "handlebars",
  "hbs",
  "html",
  "html-eex",
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
  "css",
  "less",
  "postcss",
  "sass",
  "scss",
  "stylus",
  "sugarss",
  "javascript",
  "javascriptreact",
  "reason",
  "rescript",
  "typescript",
  "typescriptreact",
  "vue",
  "svelte",
}

require("lspinstall/servers")["tailwindcss"] = {
  default_config = {
    cmd = { node.global.bin["tailwindcss-language-server"], "--stdio" },
    root_dir = root_pattern("tailwind.config.js", "tailwind.config.ts"),
    filtypes = filetypes,
  },
  install_script = install_script,
  uninstall_script = uninstall_script,
}

return {
  init_options = {
    userLanguages = {
      eelixir = "html-eex",
      eruby = "erb",
    },
  },
  settings = {
    tailwindCSS = {
      emmetCompletions = true,
    },
  },
}
