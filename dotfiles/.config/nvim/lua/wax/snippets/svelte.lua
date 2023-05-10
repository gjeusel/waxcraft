local ls = require("luasnip")
local s = ls.snippet

local i = ls.insert_node
local t = ls.text_node

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
  s("iclassnames", { t("import cn from 'classnames'") }),
}
