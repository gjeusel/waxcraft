local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
-- local i = ls.insert_node

return {
  -- libraries often used
  s("ipandas", { t("import pandas as pd") }),
  s("inumpy", { t("import numpy as np") }),
  s("ipath", { t("from pathlib import Path") }),
  s("isa", { t("import sqlalchemy as sa") }),
  -- annotations
  s("iannot", { t("from __future__ import annotations") }),
  s("itype", { t("from typing import TYPE_CHECKING, Any, Optional") }),
  s("iany", { t("from typing import Any") }),
  s("iopt", { t("from typing import Optional") }),
  -- debugger
  -- s("iforkedpdb", { t('__import__("venturi").utils.forked_pdb.ForkedPdb().set_trace()') }),
  s("iforkedpdb", { t('__import__("dagster").utils.forked_pdb.ForkedPdb().set_trace()') }),
}
