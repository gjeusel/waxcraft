#with import <nixpkgs> {};
with import "/etc/nixpkgs/" {};
stdenv.mkDerivation {
  name = "clang-env";

  src = null;

  buildInputs = [
    clangStdenv
    clang
  ];

}
