# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./sysPkgs.nix
    ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.09";

  networking = {
    hostName = "myNixHost";
    networkmanager.enable = true; # obtain an IP address and other configuration for all network interfaces that are not manually configured.
  };


  # Select internationalisation properties.
  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "fr";
    defaultLocale = "fr_FR.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.extraConfig =
  ''
    X11Forwarding yes
    X11UseLocalhost no
  '' ;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "fr";
    xkbOptions = "eurosign:e";
  };

  # DisplayManager :
  services.xserver.displayManager = {
    job.logsXsession = true; # Whether the display manager redirects the output of the session script to ~/.xsession-errors.
    sddm.enable = true;
    sddm.extraConfig = ''
    '';
  };

  # Enable the plasma5 Desktop Environment.
  services.xserver.desktopManager = {
    default = "plasma5" ;
    plasma5.enable = true;
    plasma5.enableQt4Support = false;
    xfce.enable = true;
    /*plasma5.extraPackages = [ pkgs.plasma5.plasma-nm ]; # managing connexions applet*/
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.gjeusel = {
    isNormalUser = true;
    home = "/home/gjeusel";
    extraGroups = ["users" "networkmanager" "input" "vboxsf"]; # give networkmanager permission
    uid = 1000;
    /*openssh.authorizedKeys.keys = ["ssh-dss MXPdhRqqmSW/jfpiaJyU4aN6p8FvEQAgTnMZ+cd8eUA gjeusel@myNixHost "];*/
    #password = "" ;
  };
  users.extraUsers.public = {
    isNormalUser = true;
    home = "/home/public";
    extraGroups = ["users" "networkmanager" "input" "vboxsf"]; # give networkmanager permission
    uid = 1001;
    #password = "" ;
  };

  # To allow sudo cmd to gjeusel, and give him all privileges
  security.sudo.enable = true ;
  security.sudo.extraConfig =
  ''
  Defaults:gjeusel      !authenticate
  gjeusel ALL=(ALL) ALL
  '';

  # Security:
  security.pam.services.public.allowNullPassword = true;

}
