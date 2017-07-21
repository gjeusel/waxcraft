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
  /*time.timeZone = "America/Sao_Paulo";*/

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enabling chromecast port :
  networking.firewall.allowedUDPPortRanges = [{from = 32768; to = 61000;}];
  networking.firewall.allowedTCPPorts = [8765];

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
    extraGroups = ["users" "networkmanager" "input"]; # give networkmanager permission
    uid = 1000;
    #password = "" ;
  };
  users.extraUsers.public = {
    isNormalUser = true;
    home = "/home/public";
    extraGroups = ["users" "networkmanager" "input"]; # give networkmanager permission
    uid = 1001;
    #password = "" ;
  };
  users.extraUsers.testwax = {
    isNormalUser = true;
    home = "/home/testwax";
    extraGroups = ["users" "networkmanager" "input"]; # give networkmanager permission
    uid = 1002;
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
      gutenprint = true;
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

# VPN with private internet access (PIA) :
  services.openvpn = {
    servers.pia = {
      autoStart = false;
      config = ''
        client
        dev tun
        proto udp
        remote france.privateinternetaccess.com 1198
        resolv-retry infinite
        nobind
        persist-key
        persist-tun
        cipher aes-128-cbc
        auth sha1
        tls-client
        remote-cert-tls server
        auth-user-pass
        comp-lzo
        verb 1
        reneg-sec 0
        disable-occ
        crl-verify /home/gjeusel/.pia/crl.pem
        ca /home/gjeusel/.pia/ca.crt
        auth-user-pass /home/gjeusel/.pia/auth.txt
      '';
    };
  };


}
