local ls = require("luasnip")
local fmta = require("luasnip.extras.fmt").fmta
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

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
  s("import", fmta('import { <name> } from "<pkg>"', { pkg = i(1), name = i(0) })),

  s("ilodash", { t('import ld from "lodash"') }),
  s("iremeda", { t('import * as R from "remeda"') }),
  s("izod", { t('import { z } from "zod"') }),
  s("idate-fns", { t('import * as dt from "date-fns"') }),

  -- Loops
  s(
    "forobj",
    fmta(
      [[
        for (const key in <object>) {
          <input>
        }
      ]],
      { object = i(1), input = i(0) }
    )
  ),
  s(
    "forarri",
    fmta(
      [[
        for (let i = 0; i < [array].length; i++) {
          [input]
        }
      ]],
      { array = i(1), input = i(0) },
      { delimiters = "[]" }
    )
  ),
  s(
    "forarr",
    fmta(
      [[
        for (const value of <array>) {
          <input>
        }
      ]],
      { array = i(1), input = i(0) }
    )
  ),
}
