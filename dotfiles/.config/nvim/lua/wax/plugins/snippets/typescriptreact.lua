local ls = require("luasnip")
local s = ls.snippet

-- local t = ls.text_node
local i = ls.insert_node

local dl = require("luasnip.extras").dynamic_lambda
local fmt = require("luasnip.extras.fmt").fmt
local l = require("luasnip.extras").lambda

local opts = { delimiters = "[]" }

-- https://github.com/rafamadriz/friendly-snippets/blob/main/snippets/javascript/react-ts.json

return {
  -- Template for Component
  s(
    "vsetup",
    fmt(
      [[
        import { StyleSheet, View } from 'react-native'

        export default function [](_: any) {
          return (
            <View style={styles.container}>
              []
            </View>
          )
        }

        const styles = StyleSheet.create({
          container: {}
        })
      ]],
      { dl(1, l.TM_FILENAME:gsub(".tsx", ""), {}), i(0, "") },
      opts
    )
  ),
  --
  s(
    "rn-style",
    fmt(
      [[
        const [1] = StyleSheet.create({
          [2]: {
            [3]
          }
        })
      ]],
      { i(1, "styles"), i(2, "container"), i(3, "") },
      opts
    )
  ),
}
