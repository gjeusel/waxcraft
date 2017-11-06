{ pkgs ? import "/etc/nixpkgs/" {}  }:
#{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "intraday36-nix-env";

  shellHook = ''
    export PS1=$ps1_intraday36
    export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python3.6/site-packages/
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/tshistory/
   '';

  buildInputs = [
    # Versionning :
    mercurial
    python36Packages.hglib

    python36Full
    python36Packages.pip

    # Python Common Tools :
    python36Packages.pytest
    python36Packages.ipdb # Debugger library
    python36Packages.ipython # Ipython library
    python36Packages.pyqt4 # enable display of figures
    python36Packages.six # for smoothing over the differences between the Python versions

    # SQL :
    python36Packages.psycopg2 # PostgreSQL database adapter for the Python programming language
    #python36Packages.zope_sqlalchemy # Python SQL toolkit and Object Relational Mapper that gives application developers the full power and flexibility of SQL
    #python36Packages.sqlalchemy_migrate


    python36Packages.suds-jurko # Lightweight SOAP client (Jurko's fork)
    #python36Packages.click # Create beautiful command line interfaces in Python
    python36Packages.mock # Mock objects for Python


    python36Packages.lxml # Pythonic binding for the libxml2 and libxslt libraries

    python36Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions
    #python36Packages.flask-restplus # Fast, easy and documented API development with Flask
    python36Packages.pymongo # Python driver for MongoDB

    python36Packages.xmltodict


    # Python math common libraries :
    python36Packages.plotly
    #colorlover
    python36Packages.scikitlearn
    #python36Packages.pytorch
    #python36Packages.torchvision
    #python36Packages.xgboost
    #lightgbm
    #python36Packages.graphviz

    # Dataframe handle :
    python36Packages.pandas # dataframe handle
    python36Packages.seaborn # cool color map
    #grafana
    python36Packages.ipywidgets # avoid Warning on seaborn import #874

  ];
}
