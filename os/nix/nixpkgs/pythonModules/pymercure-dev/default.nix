{stdenv, click, pm-utils, suds-jurko, pandas, inireader,  buildPythonPackage}:

buildPythonPackage rec {
  name = "pymercure-dev";

  src = /media/sf_windows/pythonModule_engie/pymercure-dev.tar.gz ;

  buildInputs = [click pm-utils suds-jurko pandas inireader];
  propagatedBuildInputs = [click pm-utils suds-jurko pandas inireader];

}


