/*let*/
/*  pkgs = import <nixpkgs> {};*/
/*in*/
/*{*/
/*  [>pathOverlays = builtins.getEnv "waxCraft_PATH"+"/nix/nixpkgs/overlays/" ;<]*/
/*  import pkgs.path { overlays = [ (self: super: {*/

/*    vim = super.vim.override {enableLua=true;};*/
/*    }) ]; }*/

/*}*/



{

#{{{
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
  enablePepperFlash = true; # Chromium's non-NSAPI alternative to Adobe Flash
  enablePepperPDF = true;
};
#}}}


#{{{

packageOverrides = super: let self = super.pkgs; in with self; rec {

  pathToMyPackages = builtins.getEnv "waxCraft_PATH"+"/nix/nixpkgs/" ;

  vim74-spf13 = self.callPackage "${pathToMyPackages}vim-7.4-spf13/default.nix" {  };
  blank_env   = self.callPackage "${pathToMyPackages}blank_env/default.nix" {  };
  cute20      = self.callPackage "${pathToMyPackages}cute-2.0/default.nix" {  };

  # Pythons modules :
  pathToMyPythonModules = builtins.getEnv "waxCraft_PATH"+"/nix/nixpkgs/pythonModules/";

  pywann = self.callPackage "${pathToMyPythonModules}PyWANN/default.nix"{
    buildPythonPackage = self.pythonPackages.buildPythonPackage;
    numpy = self.pythonPackages.numpy;
    setuptools = self.pythonPackages.setuptools;
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

};

}
