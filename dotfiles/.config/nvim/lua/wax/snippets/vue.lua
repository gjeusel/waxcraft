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
    "vcomponent",
    fmt(
      [[
        <script setup lang="ts">
        const props = defineProps<{[props]}>()
        </script>

        <template>
        </template>
      ]],
      { props = i(0) },
      opts
    )
  ),
  s(
    "vpage",
    fmt(
      [[
        <script setup lang="ts">
        definePageMeta({
          title: "[title]",
        })
        </script>

        <template>
        </template>
      ]],
      { title = i(0) },
      opts
    )
  ),
  s(
    "vscript",
    fmt(
      [[
        <script setup lang="ts">
        [input]
        </script>
      ]],
      { input = i(0) },
      opts
    )
  ),
  s("vimport", fmt([[import { [name] } from "#imports"]], { name = i(0) }, opts)),

  s(
    "vstyle",
    fmt(
      [[
        <style lang="postcss">
          [input]
        </style>
      ]],
      { input = i(0) },
      opts
    )
  ),

  s(
    "demits",
    fmt(
      [[
        const emits = defineEmits(["{emits}"])
      ]],
      { emits = i(0) }
    )
  ),

  -- Loops
  s(
    "vfor",
    fmt(
      [[
        <{tag} v-for="{iter}" :key="{key}">
          {input}
        </{tag_rep}>
      ]],
      {
        tag = c(1, tags),
        tag_rep = rep(1),
        iter = i(2),
        key = i(3),
        input = i(0),
      }
    )
  ),

  -- Conditional
  s(
    "velse",
    fmt(
      [[
        <div v-else>
          {input}
        </div>
      ]],
      { input = i(0) }
    )
  ),
  s(
    "velif",
    fmt(
      [[
        <div v-else-if="{condition}">
          {input}
        </div>
      ]],
      {
        condition = i(1),
        input = i(0),
      }
    )
  ),
  s(
    "vif",
    fmt(
      [[
        <div v-if="{condition}">
          {input}
        </div>
      ]],
      {
        condition = i(1),
        input = i(0),
      }
    )
  ),
  s(
    "velif",
    fmt(
      [[
      <div v-else-if="{condition}">
        {input}
      </div>
      ]],
      {
        condition = i(1),
        input = i(0),
      }
    )
  ),
  s(
    "velse",
    fmt(
      [[
        <div v-else>
        {input}
        </div>
      ]],
      { input = i(0, "") }
    )
  ),

  -- nuxt ui / tailwindcss
  s(
    "uiconst",
    fmt(
      [[
        const ui[constname] = /* ui */ {
          [input]
        }
      ]],
      {
        constname = i(1),
        input = i(0),
      },
      opts
    )
  ),
}
