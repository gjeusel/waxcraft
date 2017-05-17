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

packageOverrides = super: let self = super.pkgs; in with self; rec {

  pathToMyPackages = builtins.getEnv "waxCraft_PATH"+"/nix/nixpkgs/" ;

  vim74-spf13 = self.callPackage "${pathToMyPackages}vim-7.4-spf13/default.nix" {  };
  blank_env   = self.callPackage "${pathToMyPackages}blank_env/default.nix" {  };
  cute20      = self.callPackage "${pathToMyPackages}cute-2.0/default.nix" {  };
  /*cartopy     = self.callPackage "${pathToMyPackages}cartopy/default.nix" {  };*/

  # Pythons modules :
  #enzyme = self.callPackage "${pathToMyPackages}pythonModules/enzyme-0.4.2/default.nix" {
  #  python = self.python27;
  #  self = python27Packages;
  #};

  /*enzyme = self.callPackage "${pathToMyPackages}pythonModules/enzyme-0.4.2/default.nix" {};*/
  /*guessit = self.callPackage "${pathToMyPackages}pythonModules/guessit-2.1.2/default.nix" {};*/
  /*rebulk = self.callPackage "${pathToMyPackages}pythonModules/rebulk/default.nix" {};*/
  /*subliminal = self.callPackage "${pathToMyPackages}pythonModules/subliminal-2.0.5/default.nix" {};*/

  #python27Packages = super.callPackage "${pathToMyPackages}python-packages-custom.nix" {
  #  python = self.python27;
  #  self = self.python27Packages;
  #};


#  myTexLive = with pkgs; {
#       paths = [texLiveFull lmodern];
#  };

};
}
