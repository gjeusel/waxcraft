# Custom build of Lyx version 2.1.1 which is not available in the Nixpkgs 14.04
# channel as of 8/14/04.
# Modifying the expression in Nixpkgs of versiotn 2.0.7 to allow hunspell and
# enchant spell checkers.

with import {literal}&lt; nixpkgs &gt;{/literal} { #fetchurl stdenv texLive python
#pkgconfig libX11 qt4 enchant hunspell #mythes, boost
};

stdenv.mkDerivation rec {
  version = "2.1.1";
  name = "lyx-$ {literal}{version}{/literal}";

  src = fetchurl {
    url = "ftp://ftp.lyx.org/pub/lyx/stable/2.1.x/${literal}{name}{/literal}.tar.xz";
    sha256 = "1fir1dzzy7c92jf3a3psnd10c6widslk0852xk4svpl6phcg4nya";
  };

  configureFlags = [
    "--without-included-boost"
    /*  Boost is a huge dependency from which 1.4 MB of libs would be used.
        Using internal boost stuff only increases executable by around 0.2 MB. */
    "--without-included-mythes" # such a small library isn't worth a separate
    #package
  ];

  buildInputs = [
    pkgconfig qt4 python file bc texLive makeWrapper #libX11
    enchant hunspell mythes boost
  ];

  doCheck = true;

    postFixup = ''
    sed '1s:/usr/bin/python:${literal}{python}{/literal}/bin/python:'

    wrapProgram "$out/bin/lyx" \
      --prefix PATH : '${literal}{python{/literal}}/bin'
  '';

  meta = {
    description = "LyX 2.1.1 customized for local installation";
    homepage = "http://www.lyx.org";
    license = stdenv.lib.licenses.gpl2;
    maintainers = [ stdenv.lib.maintainers.vcunat ];
    platforms = stdenv.lib.platforms.linux;
  };
