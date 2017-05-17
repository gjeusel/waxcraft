{stdenv, python, fetchFromGitHub, python27Packages, enzyme, buildPythonPackage}:

buildPythonPackage rec {
  name = "subliminal-${version}";
  version = "2.0.5";

  src = fetchFromGitHub {
    owner = "Diaoul";
    repo = "subliminal";
    rev = "${version}";
    sha256 = "0is21cv9nxivag2hlglm82cv07y9qag79yiswyjbm8s41hcparsj";
  };

  buildInputs = with python27Packages; [ futures pytest
        guessit babelfish enzyme beautifulsoup4
        requests click stevedore
        chardet six appdirs rarfile
        pytz
     ];

  #propagatedBuildInputs = with self; [ numpy scipy numpy.blas ];

  #checkPhase = ''
  #${python.interpreter} test/*.py                                         #*/
  #'';

}
