local ls = require("luasnip")
local fmt = require("luasnip.extras.fmt").fmt
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

local opts = { delimiters = "[]" }

return {
  -- Console snippets
  s("cl", { t("console.log("), i(1), t(")") }),
  s("ct", { t("console.trace("), i(1), t(")") }),
  s("cd", { t("console.debug("), i(1), t(")") }),
  s("ci", { t("console.info("), i(1), t(")") }),
  s("cw", { t("console.warn("), i(1), t(")") }),
  s("ce", { t("console.error("), i(1), t(")") }),

  s("cjson", { t("console.log(JSON.stringify("), i(1), t("))") }),
  s("pprint", { t("console.log(JSON.stringify(", i(1), t(", undefined, 4)")) }),

  -- Import snippets
  s("import", fmt('import { [2] } from "[1]"', { i(1, ""), i(2, "") }, opts)),

  s("ilodash", { t('import ld from "lodash"') }),
  s("iremeda", { t('import * as R from "remeda"') }),
  s("izod", { t('import { z } from "zod"') }),
  s("idate-fns", { t('import * as dt from "date-fns"') }),

  -- Loops
  s(
    "forobj",
    fmt(
      [[
        for (const key in [object]) {
          [0]
        }
      ]],
      {
        object = i(1, "object"),
        [0] = i(0, ""),
      },
      opts
    )
  ),
  s(
    "forarri",
    fmt(
      [[
        for (let i = 0; i < [array].length; i++) {
          [0]
        }
      ]],
      {
        array = i(1, "array"),
        [0] = i(0, ""),
      },
      opts
    )
  ),
  s(
    "forarr",
    fmt(
      [[
        for (const value of [array]) {
          [0]
        }
      ]],
      {
        array = i(1, "array"),
        [0] = i(0, ""),
      },
      opts
    )
  ),
}
