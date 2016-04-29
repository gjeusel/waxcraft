{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "clang-nix-env";

  shellHook = ''
        export PS1=$ps1_clang
        '';

  buildInputs = [
    clangStdenv
    clang
    cmakeCurses
  ];

  #shellHook = ''
  #  export NIX_PATH="nixpkgs=${toString <nixpkgs>}"
  #  export LD_LIBRARY_PATH="${libvirt}/lib:$LD_LIBRARY_PATH"
  #'';

}

#cmake
#cmakeWithGui
#llvmPackages.clang-unwrapped
