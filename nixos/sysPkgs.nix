{ config, pkgs, ... }:

{

environment.systemPackages = with pkgs; [

  firefox
  imagemagick

# Extra bash commands :
  tree
  htop
  wget
  gitAndTools.gitFull

# Programming env
  gcc5
  clangStdenv
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
