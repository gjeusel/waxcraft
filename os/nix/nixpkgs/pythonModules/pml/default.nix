{stdenv, fetchFromBitbucket, buildPythonPackage}:

buildPythonPackage rec {
  name = "pml";

  src = fetchFromBitbucket {
    owner = "pythonian";
    repo = "pyhtml";
    rev = "02c4167";
    sha256 = "0iwfzbs7ykr69l8dlhkp29kb6kvhjhaxpd32raphwlgakpgib86x";
  };
  doCheck = false;

  #buildInputs = [pyyaml setuptools];
  #propagatedBuildInputs = [numpy];

  meta = {
    description = "Library for somes html tools";
    homepage = https://bitbucket.org/pythonian/pyhtml;
  };

}

