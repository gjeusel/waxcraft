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
    import numpy as np
except Exception as e:
    print("Could not import numpy: {}".format(e))

try:
    import pandas as pd
    IDX = pd.IndexSlice
    emptydf = pd.DataFrame()

    # Recent Dates aware:
    now = pd.Timestamp.now(tz='CET').replace(microsecond=0)
    end = pd.Timestamp(now, tz='CET') + pd.Timedelta(hours=4)
    start = end - pd.Timedelta(days=3)

    # DST
    dst_start = pd.Timestamp('2017-03-26T00:00:00', tz='CET')
    dst_end = pd.Timestamp('2017-03-26T04:00:00', tz='CET')

    # 2016
    start_2016 = pd.Timestamp("2016-01-01T00:00:00", tz='CET')
    end_2016 = pd.Timestamp("2017-01-01T00:00:00", tz='CET')

    # 2017
    start_2017 = pd.Timestamp("2017-01-01T00:00:00", tz='CET')
    end_2017 = pd.Timestamp("2017-01-01T00:00:00", tz='CET')

    # 2018
    start_2018 = pd.Timestamp("2018-01-01T00:00:00", tz='CET')
    end_2018 = pd.Timestamp("2018-01-01T00:00:00", tz='CET')

    # timedeltas aliases:
    onehour = pd.Timedelta(hours=1)
    tenhours = pd.Timedelta(hours=10)
    oneday = pd.Timedelta(days=1)
    oneweek = pd.Timedelta(days=7)
    onemonth = pd.Timedelta(days=31)
except Exception as e:
    print("Could not import pandas as pd: {}".format(e))

import logging
log = logging.basicConfig(format='%(asctime)s %(levelname)s:%(message)s',
                          level=logging.INFO,
                          datefmt='%I:%M:%S')

try:
    from ml_utils import plot
except Exception as e:
    print("Could not import ml_utils: {}".format(e))


CFG = None
try:
    import intraday_hub
    from intraday_hub.utils import CFG
    from intraday_hub.tankertsio import TankerTimeSerie
    tktseries = TankerTimeSerie()
    from intraday_hub.mercure import MercureClient
    mc = MercureClient()
    from intraday_hub import tourbillon
    from intraday_hub.__main__ import *
except ImportError as e:
    print("Could not import intraday_hub: {}".format(e))

try:
    engine = create_engine(CFG.db_uri.hubtest)
except:
    print('Could not initialize engine')

appd = 'application_date'
pubd = 'publication_date'

try:
    import tourbillon_client
    if CFG is not None:
        try:
            trb_local = tourbillon_client.Client(url=CFG.tourbillon.url,
                                                 token=CFG.tourbillon.token)
        except Exception:
            print("Could not initiate trb_local instance")

        try:
            trb = tourbillon_client.Client(url=CFG.tourbillon.preprodurl,
                                           token=CFG.tourbillon.preprodtoken)
        except Exception as e:
            print("Could not initiate trb_local instance: {}".format(e))

except Exception as e:
    print("Could not import tourbillon_client: {}".format(e))

try:
    from da_versus_id.ml.featureing import *
    from da_versus_id.model import DAvIDde
    da_versus_id_imported = True
    david = DAvIDde()
    # david.get_raw_data(start_2017, start_2017 + onemonth)
except ImportError as e:
    da_versus_id_imported = False
    print("Could not import da_versus_id: {}".format(e))

if da_versus_id_imported:
    try:
        import lightgbm as lgb

        params = {'learning_rate': 0.008, 'max_depth': 4,
                  'n_estimators': 100, 'num_leaves': 400}

        # params = {"max_depth": 12, "learning_rate": 0.1, "num_leaves": 10,
        #           "n_estimators": 300}

        lg = lgb.LGBMRegressor(**params, silent=False)
        david = DAvIDde(model=lg)
    except ImportError as e:
        print("Could not import lightgbm: {}".format(e))


try:
    from stmarket.inputs.gemapis import RTE, ImbalanceSettlement
    from stmarket.scrapers import elia
    from stmarket.dashboards import imbalance
    ibe = imbalance.imbalance_plot_be(now - tenhours, keep_delta_hours=None)
except ImportError as e:
    print("Could not import stmarket.scrapers.elia: {}".format(e))
