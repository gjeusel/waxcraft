{ stdenv, fetchurl, rebulk, buildPythonPackage}:

buildPythonPackage rec {
  name = "guessit-${version}";
  version = "2.1.2";

  src = fetchurl {
    url = "https://pypi.python.org/packages/15/36/7b9d57c53dd35275b6d2e47e879f3310a4d9177b268ddc90bb520830423b/guessit-2.1.2.tar.gz";
    sha256 = "15fxc59v371kbrg5vk5q5fpwh2f0dyp0m8ii8ql4hm91yavi4zlz";
  };
  doCheck = false;

  buildInputs = [rebulk];


