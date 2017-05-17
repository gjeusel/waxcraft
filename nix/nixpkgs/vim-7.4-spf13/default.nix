{ stdenv, fetchFromGitHub, ncurses, lua, pkgconfig }:

stdenv.mkDerivation rec {
  name = "vim-${version}-spf13";
  version = "7.4.1585";

  src = fetchFromGitHub {
    owner = "vim";
    repo = "vim";
    rev = "v${version}";
    sha256 = "1kjdwpka269i4cyl0rmnmzg23dl26g65k26h32w8ayzfm3kbj123";
  };

  enableParallelBluiding = true;

  buildInputs = [ ncurses lua pkgconfig ];
    #++ stdenv.lib.optionals lua; ??

  configureFlags = [
    "--enable-multibyte"            # Include multibyte editing support.
    "--enable-luainterp=yes"        # Include Lua interpreter.
    "--with-lua-prefix=${lua}"      # Give lua path
  ];

  hardeningDisable = [ "fortify" ];

  postInstall = ''
  ln -s $out/bin/vim $out/bin/vi
  '';

  crossAttrs = {
    configureFlags = [
      "vim_cv_toupper_broken=no"
      "--with-tlib=ncurses"
      "vim_cv_terminfo=yes"
      "vim_cv_tty_group=tty"
      "vim_cv_tty_mode=0660"
      "vim_cv_getcwd_broken=no"
      "vim_cv_stat_ignores_slash=yes"
      "ac_cv_sizeof_int=4"
      "vim_cv_memmove_handles_overlap=yes"
      "vim_cv_memmove_handles_overlap=yes"
      "STRIP=${stdenv.cross.config}-strip"
    ];
  };

}
