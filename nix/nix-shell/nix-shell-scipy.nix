{ pkgs ? import <nixpkgs> {}  }:
/*{ my_pkgs ? import <nixpkgs> {}  }:*/

with pkgs;

stdenv.mkDerivation {
  name = "scipy-nix-env";

  shellHook = ''
    export PS1=$ps1_scipy
   '';

  buildInputs = [
    /*python27Packages.requests # for download on web purpose*/
    /*python27Packages.appdirs*/
    /*python27Packages.chardet*/
    /*python27Packages.babelfish*/
    /*python27Packages.click*/

    python27Packages.scipy_0_17
    python27Packages.pyqt4 # enable display of figures
    python27Packages.pandas # dataframe handle
    python27Packages.seaborn # cool color map
    python27Packages.pyramid_jinja2

    python27Packages.scikitlearn # algo for data mining

    python27Packages.networkx # graph algo
    python27Packages.graph-tool
    graphviz
    python27Packages.pygraphviz # graph algo
    python27Packages.pydot

    spark

    /*myTexLive*/
    /*texlive.scheme-full*/
    /*texLiveFull*/
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
