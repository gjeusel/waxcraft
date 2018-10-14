{stdenv, fetchFromGitHub, buildPythonPackage, pyyaml, numpy, setuptools}:

buildPythonPackage rec {
  name = "pywann";

  src = fetchFromGitHub {
    owner = "firmino";
    repo = "PyWANN";
    rev = "339c4ca35eec669c2a98393eeff7dfcb4a3d96a9";
    sha256 = "0jgx4h031dv7sqsimibzd4fhqmqwdr2xdbzfp0490zdrwcvfmq1r";
    fetchSubmodules = true;
  };
  doCheck = false;

  buildInputs = [pyyaml setuptools];
  propagatedBuildInputs = [numpy];

  meta = {
    description = "Python Weightless Artificial Neural Network";
    homepage = https://github.com/firmino/firmino;
    license = "GPL-2.0";
    maintainers = [ "firmino" ];
  };

}
