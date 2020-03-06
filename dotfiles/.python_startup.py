import asyncio
import importlib
import json
import logging
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from pprint import pprint

import pytz
import urllib3

import __main__

TZ = pytz.timezone("Europe/Brussels")

log = logging.basicConfig(
    format="%(asctime)s %(levelname)s:%(message)s",
    level=logging.INFO,
    datefmt="%I:%M:%S",
)

logroot = logging.getLogger("")
logroot.setLevel(logging.INFO)

logging.getLogger("restless-client").setLevel(logging.DEBUG)

logging.getLogger("parso.python.diff").disabled = True

# Avoid logging repport when auto-complete with tab
# cd https://stackoverflow.com/questions/49442523/prevent-showing-debugging-log-info-inside-ipython-shell
logging.getLogger("parso.cache").disabled = True
logging.getLogger("parso.cache.pickle").disabled = True

for lib in [
        "requests", "urllib3", "mercure", "parso", "diff", "pickle", "cache"
]:
    logging.getLogger(lib).setLevel(logging.WARNING)

urllib3.disable_warnings()

try:
    import pandas as pd

    # Recent Dates aware:
    now = pd.Timestamp.now(tz="CET").floor("s")
    end = now + pd.Timedelta(hours=4)
    start = end - pd.Timedelta(days=3)

    # DST: Winter -> Summer
    dst_start_ws = pd.Timestamp("2017-03-26T00:00:00", tz="CET")
    dst_end_ws = pd.Timestamp("2017-03-26T04:00:00", tz="CET")

    # DST: Summer -> Winter
    dst_start_sw = pd.Timestamp("2019-10-27T00:00:00", tz="CET")
    dst_end_sw = pd.Timestamp("2019-10-28T00:00:00", tz="CET")

    # 2016
    start_2016 = pd.Timestamp("2016-01-01T00:00:00", tz="CET")
    end_2016 = pd.Timestamp("2017-01-01T00:00:00", tz="CET")

    # 2017
    start_2017 = pd.Timestamp("2017-01-01T00:00:00", tz="CET")
    end_2017 = pd.Timestamp("2017-01-01T00:00:00", tz="CET")

    # 2018
    start_2018 = pd.Timestamp("2018-01-01T00:00:00", tz="CET")
    end_2018 = pd.Timestamp("2018-01-01T00:00:00", tz="CET")

    # timedeltas aliases:
    onehour = pd.Timedelta(hours=1)
    tenhours = pd.Timedelta(hours=10)
    oneday = pd.Timedelta(days=1)
    oneweek = pd.Timedelta(days=7)
    onemonth = pd.Timedelta(days=31)

    today = now.floor("D")
    tomorrow = today + oneday
    yesterday = today - oneday

    MINDT = pd.Timestamp.min.tz_localize("UTC")
    MAXDT = pd.Timestamp.max.tz_localize("UTC")

    def gen_ts(size, start=pd.Timestamp("2020-01-01", tz="CET"), freq="1H"):
        idx = pd.date_range(start=start, freq=freq, periods=size)
        return pd.Series([1.0] * len(idx), index=idx)

except ImportError:
    pass

local_startup_file = Path.home() / ".python_startup_local.py"
if local_startup_file.exists():
    filepath = local_startup_file.as_posix()
    with open(filepath, "rb") as f:
        compiled = compile(f.read(), filepath, "exec")
    exec(compiled, __main__.__dict__, __main__.__dict__)

imports = (
    "ticts",
    "requests",
    "flask",
    ("pdops", "arkolor.pdops"),
    ("sa", "sqlalchemy"),
    "sqlalchemy.orm",  # else sa.orm not available
)
for imp in imports:
    alias = None
    if isinstance(imp, (tuple, list)):
        alias, imp = imp
    alias = alias or imp
    try:
        __main__.__dict__[alias] = importlib.import_module(imp)
    except ImportError:
        pass

try:
    from ptpython.repl import embed, run_config
except ImportError:
    pass
else:
    ctx = __main__.__dict__
    if "get_ipython" not in ctx:  # if not run from ipython
        confdir = Path.home() / ".ptpython"

        # Apply config file
        def configure(repl):
            path = confdir / "config.py"
            if path.exists():
                run_config(repl, path.as_posix())

        history_path = confdir / "history"
        new = embed(
            history_filename=history_path,
            configure=configure,
            locals=ctx,
            globals=ctx,
            title="Python REPL (ptpython)",
        )
        sys.exit(new)
