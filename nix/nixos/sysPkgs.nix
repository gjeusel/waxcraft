{ config, pkgs, ... }:

{

environment.systemPackages = with pkgs; [

# Basic usefull prog
  firefox
  imagemagick        # display cmd for pictures
  evince             # pdf reader
  pavucontrol        # pulseaudio gtk for sound configuration
  kde5.plasma-nm     # managing network connexions
  transmission-gtk   # A fast, easy and free BitTorrent client
  google-drive-ocamlfuse # Equivalent google drive
  shutter             # screen capture
  spofity

# Jeux
  wineStaging         # Allow installing windows programes
  winetricks          # Help download windows ddl

# Extra bash commands :
  tree
  htop
  wget
  which
  unzip

# Wireless tool for kde hidden wifi connect :
  wirelesstools

# Commands that help to configure :
  mkpasswd            # to encrypt password
  pciutils            # tools to check pci (ex : lspci)

# Programming env
  gcc5
  clangStdenv
  clang
  cmakeCurses
  paraview
  gnuplot
  gitAndTools.gitFull #gitk && git gui

# Personnal vim
  vim
  powerline-fonts
  xclip # to enable "*y to copy to the clipboard

# ssh :
  tigervnc

# Nix scripting
  nix-prefetch-scripts

# Favorite Terminal :
  xfce.terminal
  terminator

];
}
