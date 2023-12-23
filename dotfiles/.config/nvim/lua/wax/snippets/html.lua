local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node

local fmt = require("luasnip.extras.fmt").fmt

local opts = { delimiters = "[]" }

return {
  -- Debug / Dev
  s("pjson", fmt([[<pre>{{JSON.stringify([0])}}</pre>]], { [0] = i(0, "") }, opts)),
}
