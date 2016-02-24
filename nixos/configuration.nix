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

  nixpkgs.config.allowUnfree = true;

  # Use the gummiboot efi boot loader.
  boot.loader.gummiboot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = false;

  ## Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  #boot.loader.grub.version = 2;
  ## Define on which hard drive you want to install Grub.
  #boot.loader.grub.device = "/dev/sda";

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
  time.timeZone = "Europe/Paris";

  # List services that you want to enable:
  services = {
    xserver = {
      enable = true;                # Enable the X11 windowing system.
      layout = "fr";
      #exportConfiguration = true;   #symlink the X serveur configuration under /etc/X11/xorg.conf
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable the kde5 Desktop Environment.
  services.xserver.desktopManager.kde5.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.extraUsers.gjeusel = {
    isNormalUser = true;
    home = "/home/gjeusel";
    extraGroups = ["users"];
    uid = 1000;
    #hashedPassword = $6$fsZFrGf9r7h04$F1KbY0B5D41zizjNyxvO8Rn8nFAy0kbxNYcIaX8wUZm57F.4Wg9mPpq1fQUksh1JKLjZ9M7emJydIMT3opmeJ0 ;
  };

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "15.09";

}
