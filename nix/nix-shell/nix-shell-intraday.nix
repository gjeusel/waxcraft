{ pkgs ? import "/etc/nixpkgs/" {}  }:
#{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "intraday27-nix-env";

  shellHook = ''
    export PS1=$ps1_intraday27
    export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/
   '';

  buildInputs = [
     #Personnal vim
    (vim_configurable.override {lua=lua; python=python;})
    powerline-fonts
    xclip # to enable "*y to copy to the clipboard

    # Amazon Cloud Computing :
    aws

    # Versionning :
    mercurialFull
    tortoisehg
    python27Packages.hglib

    # Python Common Tools :
    python27Packages.pytest
    python27Packages.ipdb # Debugger library
    python27Packages.ipython # Ipython library
    python27Packages.pyqt4 # enable display of figures
    python27Packages.six # for smoothing over the differences between the Python versions
    python27Packages.tabulate # tabulation functions

    python27Packages.pathlib # appropriate semantics for different operating systems

    # SQL :
    python27Packages.psycopg2 # PostgreSQL database adapter for the Python programming language
    #python27Packages.zope_sqlalchemy # Python SQL toolkit and Object Relational Mapper that gives application developers the full power and flexibility of SQL
    python27Packages.sqlalchemy_migrate


    python27Packages.suds-jurko # Lightweight SOAP client (Jurko's fork)
    python27Packages.click # Create beautiful command line interfaces in Python
    python27Packages.mock # Mock objects for Python


    python27Packages.lxml # Pythonic binding for the libxml2 and libxslt libraries

    python27Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions
    python27Packages.flask-restplus # Fast, easy and documented API development with Flask
    python27Packages.pymongo # Python driver for MongoDB

    # PACKAGE NIX TO DO :
    # Engie packages for intraday :
    pml
    pm-utils
    pymercure-dev
    colorlover
    hg-evolve
    #python27Packages.pytest_sa_pg # PYTEST SQLALCHEMY/POSTGRES FIXTURE
    tshistory

    # Python math common libraries :
    python27Packages.plotly
    #cufflinks # plotly for panda dataframe
    python27Packages.scikitlearn
    python27Packages.pytorch
    python27Packages.torchvision
    python27Packages.xgboost
    lightgbm
    python27Packages.graphviz

    # Dataframe handle :
    python27Packages.pandas # dataframe handle
    python27Packages.seaborn # cool color map
    grafana
    python27Packages.ipywidgets # avoid Warning on seaborn import #874

  ];
}
