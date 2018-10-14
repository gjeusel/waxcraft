{stdenv, buildPythonPackage}:

buildPythonPackage rec {
  name = "pymercure-dev";

  src = fetchurl {
    url = https://pypi.python.org/packages/08/ea/4a455e92e22cc6c4a7ef37203061349e3246e0083b72aa4f9cba38631cb8/hg-evolve-6.5.0.tar.gz;
    sha256 = "1zq90hw3clxwzf6f5dkkjr35yygxm3kdzyj9jl9y6p3hm809rnld";
  };

  #src = /home/gjeusel/lib-engie/prove_team-pymercure-dev-2eeeb42913c5 ;
  #buildInputs = [click pm-utils suds-jurko pandas inireader];
  #propagatedBuildInputs = [click pm-utils suds-jurko pandas inireader];

}


