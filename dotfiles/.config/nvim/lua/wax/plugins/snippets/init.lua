local ls = require("luasnip")

return {
  all = {
    -- ls.parser.parse_snippet("$file$", "$TM_FILENAME"),
  },

  -- backend
  python = require("wax.plugins.snippets.python"),

  -- frontend
  vue = require("wax.plugins.snippets.vue"),
  typescript = require("wax.plugins.snippets.typescript"),

  -- mobile
  typescriptreact = require("wax.plugins.snippets.typescriptreact"),
}
