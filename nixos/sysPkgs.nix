{ config, pkgs, ... }:

{

environment.systemPackages = with pkgs; [

# For internet :
  chromiumWrapper
  firefoxWrapper

# ssh :
  tigervnc

# Nix scripting
  nix-prefetch-scripts

# Text editors :
  #qvim

# Extra bash commands :
  tree
  htop
  wget

# Favorite Terminal :
  xfce4-terminal

];








}
