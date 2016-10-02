{ config, pkgs, ... }:

{

environment.systemPackages = with pkgs; [

  firefox
  imagemagick    # display cmd for pictures
  evince         # pdf reader
  pavucontrol    # pulseaudio cmd for sound configuration
  kde5.plasma-nm # managing network connexions

# Extra bash commands :
  tree
  htop
  wget
  gitAndTools.gitFull #gitk && git gui
  mkpasswd            # to encrypt password
  unzip
  nox                 # make easier to find nix packages

# Programming env
  gcc5
  clangStdenv
  clang
  cmakeCurses
  paraview
  gnuplot

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
