# Add non-system directories to sys.path
# Uses a list of top level directories of any and all of your repos.

import os
import sys
from pathlib import Path
# PYTHON_MODULES_DIR_LIST = [(Path.home().absolute() / 'src')]

# for path_module in PYTHON_MODULES_DIR_LIST:
#     for p in path_module.iterdir():
#         sys.path.append(p.as_posix())

from pprint import pprint
import pytz
from datetime import datetime, timedelta

try:
    import pandas as pd
    IDX = pd.IndexSlice
except ImportError:
    print("Could not import pandas as pd")

try:
    from pandas import Timestamp, Timedelta
    # Recent Dates aware:
    now = datetime.utcnow().replace(tzinfo=pytz.utc, second=0, microsecond=0)
    end = Timestamp(now, tz='CET')
    start = end - Timedelta(days=3)

    # DST
    dst_start = pd.Timestamp('2017-03-26T00:00:00', tz='CET')
    dst_end = pd.Timestamp('2017-03-26T04:00:00', tz='CET')

    # 2016
    start_2016 = Timestamp("2016-01-01T00:00:00", tz='CET')
    end_2016 = Timestamp("2017-01-01T00:00:00", tz='CET')

except ImportError as e:
    print("Could not import pandas.Timestamp: {}".format(e))

import logging
log = logging.basicConfig(format='%(asctime)s %(levelname)s:%(message)s',
                          level=logging.INFO,
                          datefmt='%I:%M:%S')

try:
    from sqlalchemy import create_engine
except ImportError:
    print("Could not import sqlalchemy")

try:
    import intraday_hub
    from intraday_hub.utils import CFG
    from intraday_hub.tankertsio import TankerTimeSerie
    tktseries = TankerTimeSerie()
    from intraday_hub.mercure import MercureClient
    mc = MercureClient()
except ImportError as e:
    print("Could not import intraday_hub: {}".format(e))

appd = 'application_date'
pubd = 'publication_date'
