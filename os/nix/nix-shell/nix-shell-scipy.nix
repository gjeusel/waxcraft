{ pkgs ? import "/etc/nixpkgs/" {}  }:
/*{ my_pkgs ? import <nixpkgs> {}  }:*/

with pkgs;

stdenv.mkDerivation {
  name = "scipy-nix-env";

  shellHook = ''
    export PS1=$ps1_scipy
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
    python27Packages.sympy # symbolic mathematic

    # Dataframe handle :
    python27Packages.pandas # dataframe handle
    python27Packages.seaborn # cool color map
    python27Packages.ipywidgets # avoid Warning on seaborn import #874
    python27Packages.pyramid_jinja2

    # Graph package :
    python27Packages.networkx # graph algo
    /*python27Packages.graph-tool*/
    graphviz
    #python27Packages.pygraphviz # graph algo
    python27Packages.pydot

    # LaTeX :
    texlive.combined.scheme-full
    lmodern # fonts used by tex
    ghostscript # necessary for pdf to png with "convert" cmd
  ];
}

## Second version :
#let
#  pkgs = import <nixpkgs> {};
#  stdenv = pkgs.stdenv;
#with import pkgs {
#  scipyEnv = stdenv.mkDerivation rec {
#  name = "scipy-nix-env";
#  version = "1.1.1.1";
#  buildInputs = [ pkgs.clang  ];
#  };
#}
