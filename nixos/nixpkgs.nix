{ config, pkgs, ... }:

# Nixpkgs options (like repository options)

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.firefox.enableAdobeFlash = true; # for Firefox

  nixpkgs.config.chromium.enableAdobeFlash = true; # for Chromium
  nixpkgs.config.chromium.enablePepperFlash = true;
  nixpkgs.config.chromium.enablePepperPDF = true;
}
