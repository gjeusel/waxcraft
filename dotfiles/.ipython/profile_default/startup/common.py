import logging
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from pprint import pprint
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
    from intraday_hub.cli import *
except ImportError as e:
    print("Could not import intraday_hub: {}".format(e))

try:
    engine = create_engine(CFG.db_uri.hubtest)
except:
    print('Could not initialize engine')


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
    import plotly
    import plotly.graph_objs as go
except Exception as e:
    print("Could not import plotly: {}".format(e))

try:
    import plotlyink as plink
except Exception as e:
    print("Could not import plotlyink: {}".format(e))

try:
    from da_versus_id.ml.base_model import *
    from da_versus_id.ml.featureing import *
    from da_versus_id.ml.split_datas import *
    from da_versus_id.ml.tuning import *
    from da_versus_id.ml.gbensemble import *
    from da_versus_id.david_model import DAvIDde

    from da_versus_id.global_business import *

    tscv = TSSplit(n_splits=10)
    david = DAvIDde()  # david with LigthGBM
    davidxgb = DAvIDde(algo='xgboost')  # david with XGBoost
    davidgbe = DAvIDde(algo='gbensemble')  # Gradient Boosting ensemble of xgb & lgb
except ImportError as e:
    print("Could not import da_versus_id: {}".format(e))

try:
    from stmarket.inputs.gemapis import RTE, ImbalanceSettlement
    from stmarket.scrapers import elia
    from stmarket.dashboards import imbalance
    ibe = imbalance.imbalance_plot_be(now - tenhours, keep_delta_hours=None)
except ImportError as e:
    print("Could not import stmarket.scrapers.elia: {}".format(e))
