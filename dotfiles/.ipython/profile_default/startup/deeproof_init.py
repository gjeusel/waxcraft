try:
    import numpy as np
except ImportError:
    pass

from os.path import expanduser
HOME = expanduser("~")

try:
    from handle_data import *
    images = load_raw_images(n_limit=200)
except ImportError:
    pass

try:
    from model import *
    m = wrapper_model(n_limit=1000)
except ImportError:
    pass
