local ls = require("luasnip")
local fmt = require("luasnip.extras.fmt").fmt
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- Console snippets
  -- s("eowijroe", { t("eojwroeiwjirewiojrew")}),
  s("cl", { t("console.log("), i(1), t(")") }),
  s("ct", { t("console.trace("), i(1), t(")") }),
  s("cd", { t("console.debug("), i(1), t(")") }),
  s("ci", { t("console.info("), i(1), t(")") }),
  s("cw", { t("console.warn("), i(1), t(")") }),
  s("ce", { t("console.error("), i(1), t(")") }),

  s("cjson", { t("console.log(JSON.stringify("),i(1), t("))")}),

  -- Import snippets
  s("import", fmt('import { [2] } from "[1]"', { i(1, ""), i(2, "") }, { delimiters = "[]" })),
  s("ilodash", { t('import ld from "lodash"') }),
  s("pprint", { t("console.log(JSON.stringify(", i(1), t(", undefined, 4)")) }),
}
