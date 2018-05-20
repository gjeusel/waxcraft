import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
import pytz


try:
    import pandas as pd
    IDX = pd.IndexSlice
    try:
        import numpy as np
        randdf = pd.DataFrame(np.random.randn(20, 10))
        nan_randdf = randdf.copy()
        nan_randdf.loc[2:10, 4:7] = pd.core.common.np.nan
    except ImportError:
        pass
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

try:
    import plotly
    import plotly.graph_objs as go
except Exception as e:
    print("Could not import plotly: {}".format(e))

# try:
#     import cufflinks as cf
# except Exception as e:
#     print("Could not import cufflinks: {}".format(e))

try:
    import plotlyink as plink
except Exception as e:
    print("Could not import plotlyink: {}".format(e))
