{ config, pkgs, ... }:

{

environment.systemPackages = with pkgs; [

  firefox
  imagemagick    # display cmd for pictures
  evince         # pdf reader
  pavucontrol    # pulseaudio cmd for sound configuration
  kde5.plasma-nm # managing network connexions
  kde5.kio # enable extract file from dolphin
  cups           # print to pdf (= pdfcreator)

# Extra bash commands :
  tree
  htop
  wget
  gitAndTools.gitFull #gitk && git gui
  mkpasswd            # to encrypt password
  unzip
  nox                 # make easier to find nix packages
  shutter             # screen capture

# Standard Programming env
  gcc5
  clangStdenv
  clang
  cmakeCurses
  paraview
  gnuplot

# Scipy Probramming env
  python27Packages.scipy_0_17
  python27Packages.pyqt4 # enable display of figures
  python27Packages.pandas # dataframe handle
  python27Packages.seaborn # cool color map
  python27Packages.pyramid_jinja2
  python27Packages.scikitlearn # algo for data mining
  texlive.combined.scheme-full
  lmodern # fonts used by tex
  ghostscript # necessary for pdf to png with "convert" cmd


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
