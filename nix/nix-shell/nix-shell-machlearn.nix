{ pkgs ? import "/etc/nixpkgs/" {}  }:
#{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "scipy-nix-machlearn";

  shellHook = ''
    export PS1=$ps1_machlearn
   '';

  buildInputs = [
    # Python Common Tools :
    python36Packages.ipdb # Debugger library
    python36Packages.ipython # Ipython library
    python36Packages.pyqt4 # enable display of figures
    python36Packages.six # for smoothing over the differences between the Python versions

    # Python math common libraries :
    python36Packages.plotly
    dash

    python36Packages.scipy
    python36Packages.pillowfight # to access : from scipy.misc import imsave


    # Machine Learning libraries :
    python36Packages.tensorflow

    python36Packages.nltk # Natural Language ToolKit

    python36Packages.pandas # dataframe handle
    python36Packages.seaborn # cool color map
    python36Packages.ipywidgets # avoid Warning on seaborn import #874

    python36Packages.scikitlearn # algo for data mining


    # Latex :
    texlive.combined.scheme-full
    lmodern # fonts used by tex
    ghostscript # necessary for pdf to png with "convert" cmd

  ];
}
