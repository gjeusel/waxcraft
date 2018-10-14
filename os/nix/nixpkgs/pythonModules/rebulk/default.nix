{ stdenv, fetchurl, buildPythonPackage}:

buildPythonPackage rec {
  name = "rebulk-${version}";
  version = "0.8.2";

  src = fetchurl {
    url = "https://pypi.python.org/packages/58/06/5072bb14eecb98948b57ffa32120da550037fa9b64e1860190755fea97ff/rebulk-0.8.2.tar.gz";
    sha256 = "06j081k8l1i4z19xpaxx716sayh1gpb8kx7s8qfs4ybvv8dr02cc";
  };
  doCheck = false;
}


