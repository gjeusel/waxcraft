{
#{{{ Global config (firefox & chromium)
# Allow broken content (when using nixpkgs as git)
allowBroken = true;
# Allow unfree license
allowUnfree = true;

# Regarding configs
firefox = {
  enableAdobeFlash = true;
  enableGoogleTalkPlugin = true;
};

chromium = {
  enableGoogleTalkPlugin = true;
  #enablePepperFlash = true; # Chromium's non-NSAPI alternative to Adobe Flash
  #enablePepperPDF = true;
};
#}}}

#{{{ packageOverrides

packageOverrides = super: let self = super.pkgs; in with self; rec {

  wax_nixpkgs = builtins.getEnv "waxCraft_PATH"+"/nix/nixpkgs/" ;

  blank_env   = self.callPackage "${wax_nixpkgs}blank_env/default.nix" {  };
  cute20      = self.callPackage "${wax_nixpkgs}cute-2.0/default.nix" {  };

  # Pythons modules :
  wax_python = "${wax_nixpkgs}pythonModules/";

  dash = self.callPackage "${wax_python}dash/default.nix"{
    pkgs = super.pkgs;
  };

  pml     = self.callPackage "${wax_python}pml/default.nix"{
    buildPythonPackage = self.pythonPackages.buildPythonPackage;
    fetchFromBitbucket = self.fetchFromBitbucket;
  };

  pm-utils = self.callPackage "${wax_python}pm-utils/default.nix"{
    pathlib = self.pythonPackages.pathlib;
    six = self.pythonPackages.six;
    werkzeug = werkzeug;
    apscheduler = self.pythonPackages.APScheduler;
    openpyxl = self.pythonPackages.openpyxl;
    mock = self.pythonPackages.mock;
    numpy = self.pythonPackages.numpy;
    pandas = self.pythonPackages.pandas;
    requests = self.pythonPackages.requests;
    xmltodict = self.pythonPackages.xmltodict;
    buildPythonPackage = self.pythonPackages.buildPythonPackage;
  };

  pymercure-dev     = self.callPackage "${wax_python}pymercure-dev/default.nix"{
    click = self.pythonPackages.click;
    pm-utils = pm-utils;
    suds-jurko = self.pythonPackages.suds-jurko;
    pandas = self.pythonPackages.pandas;
    inireader = inireader;
    buildPythonPackage = self.pythonPackages.buildPythonPackage;
  };

  pytest_sa_pg = pythonPackages.buildPythonPackage rec {
    name = "pytest_sa_pg";
    src = fetchFromBitbucket{
      owner = "pythonian";
      repo = "pytest_sa_pg";
      rev = "44b1a8a";
      sha256 = "1a6wr3pgqla0x3m909g9bm3ivbrf7vlm7xk4bgl5g7qq2nns0v25";
    };
    buildInputs = [pythonPackages.psycopg2 pythonPackages.sqlalchemy_migrate];
  };

  #click-plugins = pythonPackages.buildPythonPackage rec {
  #  name = "click-plugins-v${version}";
  #  version = "1.0.2";
  #  src = fetchFromGitHub{
  #    owner = "click-contrib";
  #    repo = "click-plugins";
  #    rev = "${version}";
  #    sha256 = "1jgs2ga4n1iin7f7yi8z2si4hl5d77444y093yn5l0r6y7rwh51k";
  #  };
  #  buildInputs = [pythonPackages.click];
  #};

  tshistory = pythonPackages.buildPythonPackage rec {
    name = "tshistory";
    src = fetchFromBitbucket{
      owner = "pythonian";
      repo = "tshistory";
      rev = "9d3157a";
      sha256 = "0lvqdr4kr8c7ifb6k15b8czpmw461gzsw0rrb37h7mbzkafcsbvd";
    };
    buildInputs = [python27Packages.dateutil
    pythonPackages.sqlalchemy_migrate pytest_sa_pg
    pythonPackages.pathlib pythonPackages.pandas
    pythonPackages.psycopg2
    pythonPackages.click pythonPackages.mock
    click-plugins
    ];
  };

  pywann = self.callPackage "${wax_python}PyWANN/default.nix"{
    buildPythonPackage = self.pythonPackages.buildPythonPackage;
    numpy = self.pythonPackages.numpy;
    setuptools = self.pythonPackages.setuptools;
  };

  hg-evolve = pythonPackages.buildPythonPackage rec {
    name = "hg-evolve";
    src = fetchurl {
      url = https://pypi.python.org/packages/08/ea/4a455e92e22cc6c4a7ef37203061349e3246e0083b72aa4f9cba38631cb8/hg-evolve-6.5.0.tar.gz;
      sha256 = "1zq90hw3clxwzf6f5dkkjr35yygxm3kdzyj9jl9y6p3hm809rnld";
    };
    doCheck = false;
  };


  pyyaml = pythonPackages.buildPythonPackage rec {
    name = "pyyaml-${version}";
    version = "3.12";

    src = fetchFromGitHub {
      owner = "yaml";
      repo = "pyyaml";
      rev = "${version}";
      sha256 = "0pg4ni2j35rcy0yingmm8m3b98v281wsxicb44c2bd5v7k7abhpz";
    };
    doCheck = false;

    meta = {
      description = "The next generation YAML parser and emitter for Python.";
      homepage = https://github.com/yaml/pyyaml;
      license = "MIT";
      maintainers = [ "yaml" ];
    };
  };


  lightgbm = pythonPackages.buildPythonPackage rec {
    name = "lightgbm-${version}";
    version  = "2.0.7";

    src = pkgs.fetchurl {
      url = "https://pypi.python.org/packages/b0/96/1556a33fae20cf7b9c7100621a89c9bc0cad47882d1b103d5bc44c64496f/lightgbm-2.0.7.tar.gz";
      sha256 = "1q8d6m9746jralzskn5247kwr3jaghn7h639qh2dn239ych5w32c";
    };
    buildInputs = [cmake pythonPackages.scipy pythonPackages.scikitlearn];
  };

  pytablewriter = pythonPackages.buildPythonPackage rec {
    name = "pytablewriter-${version}";
    version = "v0.24.0";

    src = fetchFromGitHub {
      owner = "thombashi";
      repo = "pytablewriter";
      rev = "${version}";
      sha256 = "1isab0ssnpmlnhmlg8rjs0bqxzyynz93mw5i9q9wfjzclva4nz3d";
    };
    doCheck = false;
  };

  cufflinks = pythonPackages.buildPythonPackage rec {
    name = "cufflinks";

    src = fetchFromGitHub {
      owner = "santosjorge";
      repo = "cufflinks";
      rev = "cf5eba8ff084ed323d6aad0764a1fb0f7f2900a1";
      sha256 = "08ijq6mpjvmirlfgiq7r9dbwpqpybvj4dqsbwqg3kgyjf8ig9ydi";
    };
    buildInputs = [pythonPackages.plotly colorlover pythonPackages.pandas];
    doCheck = false;
  };

  werkzeug = pythonPackages.buildPythonPackage rec {
    name = "werkzeug-${version}";
    version = "0.12.2";

    src = fetchFromGitHub {
      owner = "pallets";
      repo = "werkzeug";
      rev = "${version}";
      sha256 = "0k2ibzzzh8sj16l3rc7b5g7arlb30vdypvlws3m2klm40674bwpq";
    };
    doCheck=false;
  };

  colorlover = pythonPackages.buildPythonPackage rec {
    name = "colorlover";
    version = "0.2";
    src = fetchFromGitHub {
      owner = "jackparmer";
      repo = "colorlover";
      rev = "d63b098530458223a985bef804ded0c9be9b00b2";
      sha256 = "1avnij7bz3rjc59qvsaw7z4mkv6kdahhpr6ws3rwgqhvvipg8aax";
    };
    doCheck=false;
  };

  inireader = pythonPackages.buildPythonPackage rec {
    name = "inireader";

    src = fetchFromBitbucket {
      owner = "pythonian";
      repo = "inireader";
      rev = "b1801ec805b60ad11f77cba744ba225883061651";
      sha256 = "03g7y4zphg7i9fyamcfz3fljm7xa9vwbd66vxwqx5rljpr9nfc7p";
    };
    doCheck = false;

  };
};

#}}}
}
