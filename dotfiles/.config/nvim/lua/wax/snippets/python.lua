require("luasnip.session.snippet_collection").clear_snippets("python")

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local fmt = require("luasnip.extras.fmt").fmt
local i = ls.insert_node

return {
  -- libraries often used
  s("ipandas", { t("import pandas as pd") }),
  s("inumpy", { t("import numpy as np") }),
  s("ipath", { t("from pathlib import Path") }),
  s("isqla", { t("import sqlalchemy as sa") }),
  s("idataclass", { t("from dataclasses import dataclass") }),
  s("iannot", { t("from __future__ import annotations") }),
  --
  s("ipdb", { t('__import__("pdb").set_trace()  # BREAKPOINT') }),
  s("ipostmortem", { t('__import__("pdb").post_mortem()  # POSTMORTEM') }),
  s("iforkedpdb", { t('__import__("dagster")._utils.forked_pdb.ForkedPdb().set_trace()') }),
  --
  s(
    "istruct",
    fmt(
      [[
        import structlog
        logger = structlog.getLogger(__name__)
      ]],
      {}
    )
  ),

  -- zefire
  s("zsite", fmt("site = m.Site.query.filter_by({0}).one()", { [0] = i(0, "") })),
  s("zspv", fmt("spv = m.AssetOwner.query.filter_by({0}).one()", { [0] = i(0, "") })),
  s("zassetmanager", fmt("am = m.AssetManager.query.filter_by({0}).one()", { [0] = i(0, "") })),
  s("zcontract", fmt("contract = m.Contract.query.filter_by({0}).one()", { [0] = i(0, "") })),
  s("zinvoice", fmt("invoice = m.Invoice.query.filter_by({0}).one()", { [0] = i(0, "") })),
}
