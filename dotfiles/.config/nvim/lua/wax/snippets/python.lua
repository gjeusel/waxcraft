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
  s("ipdb", { t('__import__("pdb").set_trace()  # BREAKPOINT') }),
  s("ipostmortem", { t('__import__("pdb").post_mortem()  # POSTMORTEM') }),
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
  -- annotations
  s("iannot", { t("from __future__ import annotations") }),
  -- debugger
  -- s("iforkedpdb", { t('__import__("venturi").utils.forked_pdb.ForkedPdb().set_trace()') }),
  s("iforkedpdb", { t('__import__("dagster").utils.forked_pdb.ForkedPdb().set_trace()') }),
  -- tests
  s(
    "pyraises",
    fmt(
      [[
        match = "{match}"
        with pytest.raises({exc}, match=match):
            {0}
      ]],
      {
        match = i(1, ""),
        exc = i(2, ""),
        [0] = i(0, ""),
      }
    )
  ),
}
