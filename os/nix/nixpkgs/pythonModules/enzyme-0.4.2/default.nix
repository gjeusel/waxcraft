{ stdenv, fetchFromGitHub, buildPythonPackage}:

buildPythonPackage rec {
  name = "enzyme-${version}";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "Diaoul";
    repo = "enzyme";
    rev = "${version}";
    sha256 = "1xcsc05c7jgph133mg19fl3mnc7q43vrlq58pkzsbybgxv8v813q";

  };
  doCheck = false;

  meta = {
    description = "Python module to parse video metadata";
    homepage = https://github.com/Diaoul/enzyme;
    license = "Apache 2.0";
    maintainers = [ "Diaoul" ];
  };

}
