{ stdenv, fetchurl, perl, tcl, lua, luafilesystem, luaposix, rsync, procps }:

stdenv.mkDerivation rec {
  name = "Lmod-${version}";

  version = "6.0.20";
  src = fetchurl {
    url = "http://github.com/TACC/Lmod/archive/${version}.tar.gz";
    sha256 = "89885202fb4d3308be9150758cde079732ba774d96a5c35b6f8ec9bfd0c58653";
  };

  buildInputs = [ perl tcl lua rsync procps ];
  propagatedBuildInputs = [ luaposix luafilesystem ];
  preConfigure = '' makeFlags="PREFIX=$out" '';

  LUA_PATH="${luaposix}/share/lua/5.2/?.lua;;";
  LUA_CPATH="${luafilesystem}/lib/lua/5.2/?.so;${luaposix}/lib/?.so;;";
  meta = {
    description = "Tool for configuring environments";
  };
}
