local ls = require("luasnip")
local s = ls.snippet
local c = ls.choice_node

local t = ls.text_node
local i = ls.insert_node
local rep = require("luasnip.extras").rep

local fmt = require("luasnip.extras.fmt").fmt

local opts = { delimiters = "[]" }

local tags = { t("div"), t("p"), t("span") }

return {
  -- Setup
  s(
    "vsetup",
    fmt(
      [[
        <template>
          <div />
        </template>

        <script setup lang="ts">
        const props = defineProps<{[0]}>()
        </script>
      ]],
      { [0] = i(0, "") },
      opts
    )
  ),
  s(
    "vstyle",
    fmt(
      [[
        <style lang="postcss">
          {0}
        </style>
      ]],
      { [0] = i(0, "") }
    )
  ),

  s(
    "demits",
    fmt(
      [[
        const emits = defineEmits(["{0}"])
      ]],
      { [0] = i(0, "") }
    )
  ),

  -- Loops
  s(
    "vfor",
    fmt(
      [[
        <{tag} v-for="{iter}" :key="{key}">
          {0}
        </{tag_rep}>
      ]],
      {
        tag = c(1, tags),
        tag_rep = rep(1),
        iter = i(2, ""),
        key = i(3, "i"),
        [0] = i(0, ""),
      }
    )
  ),

  -- Conditional
  s(
    "velse",
    fmt(
      [[
        <div v-else>
          {0}
        </div>
      ]],
      { [0] = i(0, "") }
    )
  ),
  s(
    "vif",
    fmt(
      [[
        <div v-if="{condition}">
          {0}
        </div>
      ]],
      {
        condition = i(1, ""),
        [0] = i(0, ""),
      }
    )
  ),
  s(
    "velif",
    fmt(
      [[
      <div v-else-if="{condition}">
        {0}
      </div>
      ]],
      {
        condition = i(1, ""),
        [0] = i(0, ""),
      }
    )
  ),
  s(
    "velse",
    fmt(
      [[
        <div v-else>
          [0]
        </div>
      ]],
      { [0] = i(0, "") },
      opts
    )
  ),
}
