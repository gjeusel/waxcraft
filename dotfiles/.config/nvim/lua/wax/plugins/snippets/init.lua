local ls = require("luasnip")
-- local s = ls.snippet

return {
  all = {
    -- ls.parser.parse_snippet("$file$", "$TM_FILENAME"),
    ls.parser.parse_snippet("$uuid$", '"$UUID"'),
  },

  -- backend
  python = require("wax.plugins.snippets.python"),

  -- frontend
  vue = require("wax.plugins.snippets.vue"),
  svelte = require("wax.plugins.snippets.svelte"),
  typescript = require("wax.plugins.snippets.typescript"),

  -- mobile
  typescriptreact = require("wax.plugins.snippets.typescriptreact"),
}
