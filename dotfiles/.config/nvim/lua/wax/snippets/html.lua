local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node

local fmt = require("luasnip.extras.fmt").fmt

local opts = { delimiters = "[]" }

return {
  -- Debug / Dev
  s(
    "pjson",
    fmt(
      [[
    <pre
      style="
        white-space: pre-wrap;
        overflow: auto;
        max-height: 400px;
        max-width: 800px;
        border-radius: 0.375rem;
        border-width: 1px;
        border-color: rgb(243 244 246);
      "
    >
 {{ JSON.stringify([0], null, 2) }}
    </pre>
      ]],
      { [0] = i(0, "") },
      opts
    )
  ),
}
