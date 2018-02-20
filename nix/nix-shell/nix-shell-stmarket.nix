{ pkgs ? import "/etc/nixpkgs/" {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "stmarket-nix-env";

  shellHook = ''
    export PS1=$ps1_stmarket

    export PYTHONPATH=/home/gjeusel/.local/lib/python3.6/site-packages/:$PYTHONPATH
    export PATH=$PATH:/home/gjeusel/.local/bin/

    export PYTHONPATH=/home/gjeusel/src/stmarket:$PYTHONPATH
    export PYTHONPATH=/home/gjeusel/src/intraday:$PYTHONPATH
    export PYTHONPATH=/home/gjeusel/src/pymercure-dev:$PYTHONPATH
    export PYTHONPATH=/home/gjeusel/projects/:$PYTHONPATH
    export PYTHONPATH=/home/gjeusel/projects/tanker:$PYTHONPATH
    export PYTHONPATH=/home/gjeusel/projects/tshistory:$PYTHONPATH
    export PYTHONPATH=/home/gjeusel/projects/intraday_hub:$PYTHONPATH
   '';

  buildInputs = [

    python36
    python36Packages.setuptools
    python36Packages.pip

    # Python Common Tools:
    python36Packages.ipython # Ipython library
    python36Packages.click # Create beautiful command line interfaces in Python
    python36Packages.six # for smoothing over the differences between the Python versions
    python36Packages.xmltodict
    python36Packages.arrow # better handle for datetime
    python36Packages.pyaml # read yaml files

    # Test:
    python36Packages.pytest
    python36Packages.betamax
    python36Packages.betamax-serializers
    python36Packages.responses

    python36Packages.pytestpep8
    python36Packages.pytestflakes

    python36Packages.flake8
    #python36Packages.pytest-flake8

    # Documentaion:
    python36Packages.sphinx_1_2
    python36Packages.sphinx_rtd_theme

    # Database handle:
    python36Packages.marshmallow-sqlalchemy
    python36Packages.psycopg2  # Database Adapter
    python36Packages.influxdb

    # Datascience:
    python36Packages.pandas # dataframe handle
    python36Packages.numpy
    python36Packages.scikitlearn
    python36Packages.xgboost

    # Stats:
    python36Packages.statsmodels

    # web:
    python36Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions
    #python36Packages.dash_plotly

    # plot:
    python36Packages.pyside # pyqt4 for ipython matplotlib interactive
    python36Packages.matplotlib
    python36Packages.colorlover
    python36Packages.plotly

  ];
}

