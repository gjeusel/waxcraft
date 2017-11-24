{ pkgs ? import "/etc/nixpkgs/" {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "stmarket-nix-env";

  shellHook = ''
    export PS1=$ps1_stmarket

    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pm-utils/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pyhtml/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/inireader/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pymercure/

    #export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/dash-0.19.0/
    export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/stmarket/

    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python2.7/site-packages/
    export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python3.6/site-packages/

    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/windows/src/tshistory/
   '';

  buildInputs = [

    python36
    python36Packages.setuptools
    python36Packages.pip

    # Python Common Tools:
    python36Packages.ipdb # Debugger library
    python36Packages.ipython # Ipython library
    python36Packages.click # Create beautiful command line interfaces in Python
    python36Packages.six # for smoothing over the differences between the Python versions
    python36Packages.xmltodict

    # Test:
    python36Packages.pytest
    python36Packages.betamax
    python36Packages.responses
    python36Packages.pytestpep8
    python36Packages.pytestflakes

    # Documentaion:
    python36Packages.sphinx_1_2
    python36Packages.alabaster

    # Database handle:
    python36Packages.marshmallow-sqlalchemy

    # Datascience:
    python36Packages.pandas # dataframe handle
    python36Packages.scikitlearn
    python36Packages.xgboost

    # web:
    python36Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions
    #python36Packages.dash_plotly

    # plot:
    python36Packages.colorlover
    python36Packages.plotly

  ];
}

