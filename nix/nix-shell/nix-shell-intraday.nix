{ pkgs ? import "/etc/nixpkgs/" {}  }:
#{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "intraday27-nix-env";

  shellHook = ''
    export PS1=$ps1_intraday27

    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pm-utils/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pyhtml/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/inireader/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pymercure/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/tshistory/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/intraday/

    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python2.7/site-packages/

    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python3.6/site-packages/
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/tshistory/
   '';

  buildInputs = [
    # Versionning :
    mercurial
    python27Packages.hglib

    #python27
    #python27Packages.setuptools
    python27Packages.backports_shutil_get_terminal_size
    python27Packages.pip

    # Python 2 specific libraries :
    python27Packages.configparser
    python27Packages.pathlib

    # Python Common Tools :
    python27Packages.pytest
    #python27Packages.ipdb # Debugger library
    #python27Packages.ipython # Ipython library
    #python27Packages.pyqt4 # enable display of figures
    python27Packages.six # for smoothing over the differences between the Python versions

    # SQL :
    python27Packages.psycopg2 # PostgreSQL database adapter for the Python programming language
    #python27Packages.zope_sqlalchemy # Python SQL toolkit and Object Relational Mapper that gives application developers the full power and flexibility of SQL
    #python27Packages.sqlalchemy_migrate


    python27Packages.suds-jurko # Lightweight SOAP client (Jurko's fork)
    python27Packages.click # Create beautiful command line interfaces in Python
    python27Packages.click-plugins
    python27Packages.mock # Mock objects for Python


    python27Packages.lxml # Pythonic binding for the libxml2 and libxslt libraries

    python27Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions
    #python27Packages.flask-restplus # Fast, easy and documented API development with Flask
    python27Packages.pymongo # Python driver for MongoDB

    python27Packages.xmltodict

    python27Packages.isort

    # Campeas libraries :
    inireader


    # Python math common libraries :
    python27Packages.plotly
    colorlover
    python27Packages.scikitlearn
    #python27Packages.pytorch
    #python27Packages.torchvision
    #python27Packages.xgboost
    #lightgbm
    #python27Packages.graphviz

    # Dataframe handle :
    python27Packages.pandas # dataframe handle
    python27Packages.seaborn # cool color map
    #grafana
    python27Packages.ipywidgets # avoid Warning on seaborn import #874

  ];
}
