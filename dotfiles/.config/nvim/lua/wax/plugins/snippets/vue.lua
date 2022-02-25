local ls = require("luasnip")
local s = ls.snippet
-- local t = ls.text_node
local i = ls.insert_node

local fmt = require("luasnip.extras.fmt").fmt

return {
  -- s("vfor", { t('<div v-for="'), i(1), t('" :key="'), i(2), t('">') , i(3), t("")}),
  s(
    "vfor",
    fmt(
      [[
    <div v-for="{1}" :key="{2}">
      {3}
    </div>
  ]],
      { i(1, ""), i(2, "i"), i(3, "") }
    )
  ),
  s(
    "vsetup",
    fmt(
      [[
  <template>
  </template>

  <script setup lang="ts">
  const props = defineProps<{1}>()
  </script>
  ]],
      { i(1, "") }
    )
  ),
}
