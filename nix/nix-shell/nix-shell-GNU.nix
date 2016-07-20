{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "GNU-nix-env";

  shellHook = ''
    export PS1=$ps1_GNU
   '';

  buildInputs = [
    cmakeCurses
    gfortran
    ctags
  ];

  #shellHook = ''
  #  export NIX_PATH="nixpkgs=${toString <nixpkgs>}"
  #'';

}
