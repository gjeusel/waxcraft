{ stdenv, python, cmake }:

stdenv.mkDerivation rec {
  name = "blank_env";

  buildInputs = [ python cmake];
}
