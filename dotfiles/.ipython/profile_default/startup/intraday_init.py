from datetime import datetime, timedelta
fcst_offset_range=(timedelta(hours=24), timedelta(hours=48))

try:
    import numpy as np
except ImportError:
    pass

from os.path import expanduser
home = expanduser("~")

try:
    from pm_utils.config import config
    cfg = config(path=home+'/src/intraday/intraday.cfg')
    from sqlalchemy import create_engine
    engine = create_engine(cfg['db']['intraday'])
except ImportError:
    pass


start_date = datetime(2017, 10, 28)
end_date = start_date + timedelta(days=2)

try:
    import pandas as pd
    IDX = pd.IndexSlice
    dst_range_naive = pd.DatetimeIndex(
        start=datetime(2017, 10, 28, 22),
        end=datetime(2017, 10, 29, 3),
        freq='30T',
    )

    dst_range_aware = pd.DatetimeIndex(
        start=datetime(2017, 10, 29, 0),
        end=datetime(2017, 10, 29, 3),
        freq='30T',
        tz='Europe/Brussels',
    )
except ImportError:
    pass


countries = ['fr', 'de', 'be', 'nl']

lst_idrefs = [510, 509, 552, 7070]

try:
    from intraday.idvid_de_strategy import IdvidStrategy
    model_config = cfg['idvid_operational_model']
    strategy = IdvidStrategy(kind_avg='exp', is_live=True, conn=engine,
                             tradescn=None)
except ImportError:
    pass
