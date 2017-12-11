{ pkgs ? import "/etc/nixpkgs/" {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "stmarket-nix-env";

  shellHook = ''
    export PS1=$ps1_deeproof
    #export PYTHONPATH=$PYTHONPATH:/home/gjeusel/.local/lib/python3.6/site-packages/
   '';

  buildInputs = [

    python36
    python36Packages.setuptools
    python36Packages.pip

    # Python Common Tools:
    python36Packages.ipdb # Debugger library
    python36Packages.ipython # Ipython library
    python36Packages.pyqtgraph # enable display of figures inside ipython
    python36Packages.notebook # Jupyter notebook
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
    python36Packages.sphinx_rtd_theme

    # Database handle:
    python36Packages.marshmallow-sqlalchemy

    # Datascience:
    python36Packages.pandas # dataframe handle
    python36Packages.scikitlearn
    python36Packages.xgboost

    python36Packages.pypillowfight
    bazel
    #python36Packages.tensorflow
    python36Packages.pytorch
    python36Packages.torchvision

    # web:
    python36Packages.flask # A microframework based on Werkzeug, Jinja 2, and good intentions
    #python36Packages.dash_plotly

    # plot:
    python36Packages.colorlover
    python36Packages.plotly
    python36Packages.matplotlib

  ];
}


