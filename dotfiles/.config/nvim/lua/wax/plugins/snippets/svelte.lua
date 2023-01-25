local ls = require("luasnip")
local s = ls.snippet

local i = ls.insert_node

local fmt = require("luasnip.extras.fmt").fmt

local opts = { delimiters = "[]" }

return {
  s(
    "svsetup",
    fmt(
      [[
        <script lang="ts">
          [0]
        </script>
      ]],
      { [0] = i(0, "") },
      opts
    )
  ),
}
