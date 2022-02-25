local ls = require("luasnip")
local s = ls.snippet
local c = ls.choice_node

local t = ls.text_node
local i = ls.insert_node
local rep = require("luasnip.extras").rep

local fmt = require("luasnip.extras.fmt").fmt

return {
  s(
    "vfor",
    fmt(
      [[
        <{tag} v-for="{iter}" :key="{key}">
          {0}
        </{tag_rep}>
      ]],
      {
        tag = c(1, { t("div "), t("span ") }),
        tag_rep = rep(1),
        iter = i(2, ""),
        key = i(3, "i"),
        [0] = i(0, ""),
      }
    )
  ),
  s(
    "vsetup",
    fmt(
      [[
        <template>
        </template>

        <script setup lang="ts">
        const props = defineProps<{[1]}>()
        </script>
      ]],
      { i(1, "") },
      { delimiters = "[]" }
    )
  ),
}
