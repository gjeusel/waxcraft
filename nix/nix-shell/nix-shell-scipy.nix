{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "scipy-nix-env";

  shellHook = ''
    export PS1=$ps1_scipy
   '';

  buildInputs = [
    python27Packages.scipy_0_17
    python27Packages.pyqt4
    python27Packages.pandas
    python27Packages.seaborn
  ];
}
