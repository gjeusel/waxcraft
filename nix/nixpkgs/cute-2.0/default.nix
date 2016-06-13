{ stdenv, fetchurl}:

stdenv.mkDerivation rec {
  name = "cute-${version}";
  version = "2.0";

  src = fetchurl {
    url = "http://www.cute-test.com/attachments/download/87/cute2_0_0.tar.gz";
    md5 = "fffc84e31fecb938b1113c5c4113b5e4";
  };

  builder = ./builder.sh;

  #unpackPhase = ''
  #  # The archives hierarchy isn't well named, we need to handle this manually :
  #  mkdir $out/lib
  #  tar zxvf $src --directory=$out/lib --transform 's,cute_lib/,,' --wildcards --no-anchore "cute_lib/*"
  #  ln -s $out/lib/ $out/lib64/

  #  # Extract examples
  #  mkdir $out/examples
  #  tar zxvf $src --directory=$out/examples --transform 's,cute_examples/,,' --wildcards --no-anchore "cute_examples/*"

  #  # Extract tests
  #  mkdir $out/tests
  #  tar zxvf $src --directory=$out/tests --transform 's,cute_tests/,,' --wildcards --no-anchore "cute_tests/*"
  #'';

}
