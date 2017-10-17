# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
   ./hardware-configuration-VM.nix
      ./sysPkgs.nix
    ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "17.09";

  networking = {
    hostName = "myNixHost";
    networkmanager.enable = true; # obtain an IP address and other configuration for all network interfaces that are not manually configured.

    # Proxy inside VM engie :
    interfaces.enp0s3.ip4 = [
      /*{ address = "10.0.0.1"; prefixLength = 16; }*/
      { address = "192.168.56.2"; prefixLength = 24; }
    ];

    defaultGateway = "192.168.56.1";
    nameservers = [ "8.8.8.8" ];

    proxy.default = "http://proxy.eib.electrabel.be:8080";
  };

  # Postgresql config :
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql96;
    enableTCPIP = true;
    authentication = pkgs.lib.mkForce ''
# Generated file; do not edit!
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local all all trust
host    all             all             all                     md5
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
'';
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
  /*networking.firewall.allowedTCPPorts = [ 22 ]; # enabled by default when openssh enabled*/

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
  security.pam.services.testwax.allowNullPassword = true;

}
