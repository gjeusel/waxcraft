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

  --
  -- In template --
  --
  ls.parser.parse_snippet(
    { trig = "pjson", name = "json stringify in pre tag" },
    [[
      <pre>{JSON.stringify($0)}</pre>
    ]]
  ),
  ls.parser.parse_snippet(
    { trig = "seach", name = "Svelte Each Block" },
    [[
      {#each $1 as $2 ($3)}
        $0
      {/each}
    ]]
  ),
  ls.parser.parse_snippet(
    { trig = "sif", name = "Svelte If Block" },
    [[
      {#if $1}
        $0
      {/if}
    ]]
  ),
  ls.parser.parse_snippet(
    { trig = "sifelse", name = "Svelte If Else Block" },
    [[
      {#if $1}
        $2
      {:else}
        $0
      {/if}
    ]]
  ),
  ls.parser.parse_snippet(
    { trig = "sifelif", name = "Svelte If Else If Else Block" },
    [[
      {#if $1}
        $2
      {:else if $3}
        $4
      {:else}
        $0
      {/if}
    ]]
  ),
}
