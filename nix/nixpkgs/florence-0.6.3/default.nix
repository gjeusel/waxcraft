{ stdenv, intltool, gettext, perl-XML-Parser, glib, pkgconfig, gnome-doc-utils, rarian}:

##{{{

#stdenv.mkDerivation rec {
#  name = "vim-${version}-spf13";
#  version = "7.4.1054";

#  src = fetchFromGitHub {
#    owner = "brammool";
#    repo = "vim";
#    rev = "v${version}";
#    sha256 = "1cjnfjv342y9clbi88hxdxqczj3kn9hqcqyg9bj4l4v2m9mddmjw";
#  };

#  enableParallelBluiding = true;

#  buildInputs = [ ncurses lua pkgconfig ];
#    #++ stdenv.lib.optionals lua; ??

#  configureFlags = [
#    "--enable-multibyte"            # Include multibyte editing support.
#    "--enable-luainterp=yes"        # Include Lua interpreter.
#    "--with-lua-prefix=${lua}"      # Give lua path
#  ];

#  postInstall = "ln -s $out/bin/vim $out/bin/vi";
#}

##}}}
