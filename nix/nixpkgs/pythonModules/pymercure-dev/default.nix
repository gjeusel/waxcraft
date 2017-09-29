{stdenv, click, pm-utils, suds-jurko, pandas, inireader,  buildPythonPackage}:

buildPythonPackage rec {
  name = "pymercure-dev";

  src = /home/gjeusel/lib-engie/prove_team-pymercure-dev-2eeeb42913c5 ;

  buildInputs = [click pm-utils suds-jurko pandas inireader];
  propagatedBuildInputs = [click pm-utils suds-jurko pandas inireader];

}


