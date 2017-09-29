{ pkgs ? import "/etc/nixpkgs/" {}  }:
#{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "scipy-nix-machlearn";

  shellHook = ''
    export PS1=$ps1_machlearn
   '';

  buildInputs = [

    # Personnal vim
    (vim_configurable.override {lua=lua; python=python;})
    powerline-fonts
    xclip # to enable "*y to copy to the clipboard

    # Python Common Tools :
    python27Packages.ipdb # Debugger library
    python27Packages.ipython # Ipython library
    python27Packages.pyqt4 # enable display of figures
    python27Packages.six # for smoothing over the differences between the Python versions

    # Python math common libraries :
    python27Packages.matplotlib
    python27Packages.plotly
    python27Packages.scipy
    python27Packages.pillowfight # to access : from scipy.misc import imsave


    # Machine Learning libraries :
    python27Packages.tensorflow

    python27Packages.nltk # Natural Language ToolKit

    python27Packages.pandas # dataframe handle
    python27Packages.seaborn # cool color map
    python27Packages.ipywidgets # avoid Warning on seaborn import #874
    python27Packages.pyramid_jinja2

    python27Packages.scikitlearn # algo for data mining
    #pywann # Python Weightless Neural Network

    #spark

    /*myTexLive*/
    /*texlive.scheme-full*/
    /*texLiveFull*/
    texlive.combined.scheme-full
    lmodern # fonts used by tex
    ghostscript # necessary for pdf to png with "convert" cmd

  ];
}
