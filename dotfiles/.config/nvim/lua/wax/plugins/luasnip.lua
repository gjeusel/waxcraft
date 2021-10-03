local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

local types = require("luasnip.util.types")
-- local conds = require("luasnip.extras.conditions")

-- Every unspecified option will be set to the default.
ls.config.set_config({
  history = true,
  -- Update more often, :h events for more info.
  updateevents = "TextChanged,TextChangedI",
  -- ext_opts = {
  --   [types.choiceNode] = {
  --     active = {
  --       virt_text = { { "choiceNode", "Comment" } },
  --     },
  --   },
  -- },
  -- treesitter-hl has 100, use something higher (default is 200).
  ext_base_prio = 300,
  -- minimal increase in priority.
  ext_prio_increase = 1,
  enable_autosnippets = false,
})

local frontend_console = {
  s("cl", { t("console.log("), i(1), t(")") }),
  s("ct", { t("console.trace("), i(1), t(")") }),
  s("cd", { t("console.debug("), i(1), t(")") }),
  s("ci", { t("console.info("), i(1), t(")") }),
  s("cw", { t("console.warn("), i(1), t(")") }),
  s("ce", { t("console.error("), i(1), t(")") }),
}

ls.snippets = {
  all = {},
  python = {
    s("ipandas", { t("import pandas as pd") }),
    s("inumpy", { t("import numpy as np") }),
    s("iannot", { t("from __future__ import annotations") }),
  },
  typescript = frontend_console,
  vue = {},
}

ls.filetype_extend("vue", { "typescript" })
