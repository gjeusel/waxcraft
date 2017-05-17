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
  system.stateVersion = "17.03";

  nixpkgs.config.allowUnfree = true;

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
  #time.timeZone = "Europe/Paris";
  time.timeZone = "America/Sao_Paulo";

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.layout = "fr";
  services.xserver.xkbOptions = "eurosign:e";

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable the kde5 Desktop Environment.
  /*services.xserver.desktopManager.kde5.enable = true;*/
  services.xserver.desktopManager.plasma5 = true;

  # users.mutableUsers to false, then the contents of /etc/passwd and /etc/group will be congruent to your NixOS configuration
  #users.mutableUsers = false;
  # Then the root user need to set the root password :
  #users.extraUsers.root = {
  #  #To generate hashed password install mkpasswd package and run mkpasswd -m sha-512
  #  hashedPassword = "$6$Pca3Dpr18$3slalzLnqCndilfsgmkgggudIiXySGATwnTlfd3jYNd5o6Ak9c8l2MrpqroP7U2QLNM04gx/T4r.sSxF7CVHM." ;
  #};

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.gjeusel = {
    isNormalUser = true;
    home = "/home/gjeusel";
    extraGroups = ["users" "networkmanager"]; # give networkmanager permission
    uid = 1000;
    #password = "" ;
  };

  # To allow sudo cmd to gjeusel, and give him all privileges
  security.sudo.enable = true ;
  security.sudo.extraConfig =
  ''
  Defaults:gjeusel      !authenticate
  gjeusel ALL=(ALL) ALL
  '';

  # Add CUPS to print documents.
  services.printing = {
      enable = true;
      drivers = [ pkgs.hplipWithPlugin  ];
  };

  /*# Allowing Samba : network sharing soft*/
  /*services.samba = {*/
  /*  enable = true;*/
  /*  shares = {*/
  /*    data =*/
  /*      { comment = "Guigz samba share.";*/
  /*        path = "/home/gjeusel/Downloads";*/
  /*        browseable = "yes";*/
  /*        "guest ok" = "no";*/
  /*        "valid users" = "gjeusel";*/
  /*        "read only" = "true";*/
  /*       };*/
  /*  };*/
  /*  extraConfig = ''*/
  /*  guest account = nobody*/
  /*  map to guest = bad user*/
  /*  '';*/
  /*};*/

}
