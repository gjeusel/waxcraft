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
        <pre class="whitespace-pre-wrap overflow-auto max-w-lg max-h-[height] border border-gray-200">{{
          JSON.stringify([0], null, 2)
        }}</pre>
      ]],
      { [0] = i(0, ""), height = i(0, "[32rem]") },
      opts
    )
  ),
}
