local ls = require("luasnip")
-- local s = ls.snippet

return {
  all = {
    -- ls.parser.parse_snippet("$file$", "$TM_FILENAME"),
    ls.parser.parse_snippet("$uuid$", '"$UUID"'),
  },

  -- backend
  python = require("wax.snippets.python"),

  -- frontend
  vue = require("wax.snippets.vue"),
  svelte = require("wax.snippets.svelte"),
  typescript = require("wax.snippets.typescript"),

  -- mobile
  typescriptreact = require("wax.snippets.typescriptreact"),
}
