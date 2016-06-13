{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "clang-nix-env";

  shellHook = ''
    export PS1=$ps1_clang
    export LD_LIBRARY_PATH="${cute20}/lib:$LD_LIBRARY_PATH"
   '';

  buildInputs = [
    clangStdenv
    clang
    cmakeCurses
    cute20
  ];

  #shellHook = ''
  #  export NIX_PATH="nixpkgs=${toString <nixpkgs>}"
  #'';

}

#cmake
#cmakeWithGui
#llvmPackages.clang-unwrapped
