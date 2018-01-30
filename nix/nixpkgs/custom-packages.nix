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

  vimFull = self.vim_configurable.override{python = self.python36;};

  # Pythons modules :
  wax_python = "${wax_nixpkgs}pythonModules/";

  pyaml = pythonPackages.buildPythonPackage rec {
    pname = "pyaml";
    name = "${pname}-${version}";
    version = "17.12.1";

    src = pythonPackages.fetchPypi {
      inherit pname version;
      sha256 = "7dda3e0b1b12215e3bb05368d1abbf7d747112a43738e0a4e6deb466b83fd88e";
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
