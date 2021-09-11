local root_pattern = require("lspconfig").util.root_pattern
local node = require("wax.lsp.nodejs-utils")

local install_script = node.global.bin.npm .. " install -g @tailwindcss/language-server"
local uninstall_script = node.global.bin.npm .. " uninstall -g @tailwindcss/language-server"

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

require("lspinstall/servers")["tailwindcss"] = {
  default_config = {
    cmd = { node.global.bin["tailwindcss-language-server"], "--stdio" },
    root_dir = root_pattern("tailwind.config.js", "tailwind.config.ts"),
    filetypes=filetypes,
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
  filtypes = filetypes,
  settings = {
    tailwindCSS = {
      emmetCompletions = true,
    },
  },
}
