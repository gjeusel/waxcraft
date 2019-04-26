import json
import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from pprint import pprint

import pytz
import urllib3

TZ = pytz.timezone('Europe/Brussels')

log = logging.basicConfig(
    format="%(asctime)s %(levelname)s:%(message)s",
    level=logging.INFO,
    datefmt="%I:%M:%S",
)

logroot = logging.getLogger('')
logroot.setLevel(logging.INFO)

logging.getLogger('parso.python.diff').disabled = True

# Avoid logging repport when auto-complete with tab
# cd https://stackoverflow.com/questions/49442523/prevent-showing-debugging-log-info-inside-ipython-shell
logging.getLogger('parso.cache').disabled = True
logging.getLogger('parso.cache.pickle').disabled = True

for lib in [
        "requests", "urllib3", "mercure", "parso", "diff", "pickle", "cache"
]:
    logging.getLogger(lib).setLevel(logging.WARNING)

urllib3.disable_warnings()

try:
    import pandas as pd
    from pandas.io.json import json_normalize

    IDX = pd.IndexSlice
    try:
        import numpy as np

        randdf = pd.DataFrame(np.random.randn(20, 10))
        nan_randdf = randdf.copy()
        nan_randdf.loc[2:10, 4:7] = pd.core.common.np.nan
    except ImportError:
        pass

    emptydf = pd.DataFrame()

    # Recent Dates aware:
    now = pd.Timestamp.now(tz="CET").replace(microsecond=0)

    end = pd.Timestamp(now, tz="CET") + pd.Timedelta(hours=4)
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

    today = now.floor('D')
    tomorrow = today + oneday

    def generate_ts(freq):
        idx = pd.date_range(
            start='2018-01-01', end='2018-01-02', freq=freq, closed='left')
        idx = idx.tz_localize('CET')
        return pd.DataFrame(data={'value': range(len(idx))}, index=idx)

except ImportError as err:
    print("Could not import pandas as pd: {}".format(err))

local_init_path = Path(__file__).parent / 'ipythoninit_local.py'
if local_init_path.exists():
    from ipythoninit_local import *
