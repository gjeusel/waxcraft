# ruff: noqa: F401, E501, E402, E731

import importlib
import logging
import os
import subprocess
import sys
import warnings
from pathlib import Path
from pprint import pprint

import __main__

pdb = lambda: __import__("pdb").set_trace()  # BREAKPOINT

for exc in (FutureWarning,):
    warnings.filterwarnings("ignore", category=exc)

try:
    import pytz

    TZ = pytz.timezone("Europe/Brussels")
except ImportError:
    pass


# Setup logs for prompt

logging.basicConfig(
    format="%(asctime)s %(levelname)s:%(message)s",
    level=logging.INFO,
    datefmt="%I:%M:%S",
)

logroot = logging.getLogger("")
logroot.setLevel(logging.INFO)

for lib in ("parso.python.diff", "parso.cache", "parso.cache.pickle"):
    logging.getLogger(lib).disabled = True

warning_libs = ("requests", "urllib3", "parso", "diff", "pickle", "cache")
for lib in warning_libs:
    logging.getLogger(lib).setLevel(logging.WARNING)


try:
    from rich.console import Console
    from rich.theme import Theme

    _console_rich = Console(
        theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())
    )
    print = pp = _console_rich.print
except ImportError:
    pass
except Exception:
    print("Failed rich setup")

try:
    import pandas as pd
except ImportError:
    pass
else:
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


# Compile and Exec local config
local_startup_file = Path(__file__).parent / "local_startup.py"
if local_startup_file.exists():
    filepath = local_startup_file.as_posix()
    with open(filepath, "rb") as f:
        compiled = compile(f.read(), filepath, "exec")
    exec(compiled, __main__.__dict__, __main__.__dict__)


def import_in_ctx(pkg, alias=None):
    if isinstance(pkg, (tuple, list)):
        alias, pkg = pkg
    alias = alias or pkg
    try:
        __main__.__dict__[alias] = importlib.import_module(pkg)
    except ImportError:
        pass


try:
    from devtools import debug  # noqa
except Exception:
    pass


imports = (
    "httpx",
    "flask",
    # ("sa", "sqlalchemy"),
    ("debug", "devtools.debug"),
)
for pkg in imports:
    if isinstance(pkg, (tuple, list)):
        import_in_ctx(*pkg)
    else:
        import_in_ctx(pkg)


_ptpython_conf_dir = Path(
    os.environ.get("PTPYTHON_CONFIG_HOME", Path.home() / ".ptpython")
)


def _deduce_history_file():
    cmd = __main__.__file__

    #  If entered by flask shell:
    if cmd.endswith("/bin/flask"):
        return _ptpython_conf_dir / "flask_ctx_history"
    else:
        return _ptpython_conf_dir / "history"


def _ptpython_configure(repl):
    from ptpython.repl import run_config

    path = _ptpython_conf_dir / "config.py"
    if path.exists():
        run_config(repl, path.as_posix())


try:
    from ptpython.repl import embed
except ImportError:
    pass
else:
    # if not run from ipython
    if "get_ipython" not in __main__.__dict__:
        new = embed(
            history_filename=_deduce_history_file().as_posix(),
            configure=_ptpython_configure,
            locals=__main__.__dict__,
            globals=globals(),
            title="Python REPL (ptpython)",
        )
        sys.exit(new)
