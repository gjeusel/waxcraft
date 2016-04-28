{ pkgs ? import <nixpkgs> {}  }:

with pkgs;

stdenv.mkDerivation {
  name = "clang-nix-env";

  buildInputs = [
    clangStdenv
    clang
  ];

  #shellHook = ''
  #  export NIX_PATH="nixpkgs=${toString <nixpkgs>}"
  #  export LD_LIBRARY_PATH="${libvirt}/lib:$LD_LIBRARY_PATH"
  #'';

}

#cmake
#cmakeWithGui
#llvmPackages.clang-unwrapped
