{ config, pkgs, ... }:

{

environment.systemPackages = with pkgs; [

  firefox
  google-chrome
  imagemagick    # display cmd for pictures
  evince         # pdf reader
  pavucontrol    # pulseaudio cmd for sound configuration
  kde5.plasma-nm # managing network connexions

# Extra bash commands :
  tree
  htop
  wget
  gitAndTools.gitFull #gitk && git gui
  passwd              # users password management
  mkpasswd            # to encrypt password

# Programming env
  gcc5
  clangStdenv
  clang
  cmakeCurses

# Personnal vim
  vim
  powerline-fonts

# ssh :
  tigervnc

# Nix scripting
  nix-prefetch-scripts


# Favorite Terminal :
  xfce.terminal
  terminator

];


}
