{ config, pkgs, ... }:

{
# Set of packages that will appear in /run/current-system/sw :
environment.systemPackages = with pkgs; [

# Some softwares usefulls :
  firefox
  imagemagick    # display cmd for pictures
  evince         # pdf reader
  pavucontrol    # pulseaudio cmd for sound configuration
  cups           # print to pdf (= pdfcreator)

  plasma5.plasma-nm # managing network connexions

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
  python27Packages.pyqtgraph # enable display of figures
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
  nix-prefetch-scripts # to get SHA or MD5 for nixpkgs files

# Favorite Terminal :
  xfce.terminal
  #terminator
];

## some pkgs that need additional config :
#environment = {
#    # To set Oxygen-GTK as the gtk theme
#    systemPackages = [ pkgs.oxygen_gtk  ];
#    shellInit = ''
#      export GTK_PATH=$GTK_PATH:${pkgs.oxygen_gtk}/lib/gtk-2.0
#      export GTK2_RC_FILES=$GTK2_RC_FILES:${pkgs.oxygen_gtk}/share/themes/oxygen-gtk/gtk-2.0/gtkrc
#    '';
#};

}
