# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #./desktop-applications.nix
      ./sysPkgs.nix
      #./nixpkgs.nix
      #./hosts.nix
      #./hardware.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "nixos"; # Define your hostname.
  #networking.wireless.enable = true;  # Enables wireless.
  #networking.networkmanager.enable = true;

  # Select internationalisation properties.
  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "fr";
    defaultLocale = "fr_FR.UTF-8";
  };

  # Set your time zone.
  #time.timeZone = "Europe/Paris";
  time.timeZone = "America/Sao_Paulo";

  # List services that you want to enable:
  services = {
    xserver = {
      enable = true;                # Enable the X11 windowing system.
      layout = "fr";
      exportConfiguration = true;   #symlink the X serveur configuration under /etc/X11/xorg.conf
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable the kde5 Desktop Environment.
  services.xserver.desktopManager.kde5.enable = true;

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
    extraGroups = ["users"];
    uid = 1000;
    #password = "" ;
  };

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.03";

}
