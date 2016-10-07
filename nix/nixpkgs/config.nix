{

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

packageOverrides = super: let self = super.pkgs; in with self; rec {

  pathToMyPackages = builtins.getEnv "waxCraft_PATH"+"/nix/nixpkgs/" ;
  vim74-spf13 = self.callPackage "${pathToMyPackages}vim-7.4-spf13/default.nix" {  };
  blank_env   = self.callPackage "${pathToMyPackages}blank_env/default.nix" {  };
  cute20      = self.callPackage "${pathToMyPackages}cute-2.0/default.nix" {  };
  cartopy     = self.callPackage "${pathToMyPackages}cartopy/default.nix" {  };

  /*lmod        = self.callPackage "${pathToMyPackages}lmod/default.nix" {*/
  /*    inherit (self.luaPackages) luafilesystem;*/
  /*    inherit luaposix;*/
  /*};*/

};

/*packageOverrides = super: rec {*/

/*# super = paquet des dépot de départ*/
/*# on peut renommer super en nixpkgs*/

/*# Pour faire une référence au package vim dans les paquets officiels de nix :*/
/*  vim = super*/

/*  pathToMyPackages = "/root/projects/pumped-nix/" ;*/
/*  vim74-spf13 = super.pkgs.callPackage "${pathToMyPackages}vim-7.4-spf13/default.nix" {  };*/
/*  blank_env   = super.pkgs.callPackage "${pathToMyPackages}blank_env/default.nix" {  };*/

/*  lmod        = self.callPackage "${pathToMyPackages}lmod/default.nix" {*/
/*      inherit (self.luaPackages) luafilesystem;*/
/*      inherit luaposix;*/
/*  };*/

/*};*/

}
