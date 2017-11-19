{ pkgs ? import "/etc/nixpkgs/" {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "stmarket-nix-env";

  shellHook = ''
    export PS1=$ps1_stmarket

    #export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/pymercure/
    #export PYTHONPATH=$PYTHONPATH:/media/sf_windows/src/stmarket

    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python2.7/site-packages/
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python3.6/site-packages/

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
    python36Packages.pytest
    python36Packages.click # Create beautiful command line interfaces in Python
    python36Packages.six # for smoothing over the differences between the Python versions

    # Documentaion:
    python36Packages.sphinx_1_2

    # Database handle:
    python36Packages.marshmallow-sqlalchemy

    # Datascience:
    python36Packages.pandas # dataframe handle
    python36Packages.scikitlearn
    python36Packages.xgboost

    # web:
    python36Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions

    # plot:
    python36Packages.plotly
    #colorlover

  ];
}

