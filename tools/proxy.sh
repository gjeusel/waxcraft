export ftp_proxy="http://proxy.eib.electrabel.be:8080"
export rsync_proxy=$http_proxy
export no_proxy=
export http_proxy="http://proxy.eib.electrabel.be:8080/"
export https_proxy="https://proxy.eib.electrabel.be:8080/"
export rsync_proxy=$http_proxy
export ftp_proxy=$http_proxy
export NIX_REMOTE=""

setProxy() {
  export NIX_REMOTE=""
  export http_proxy=$1
  export https_proxy=$1
  export ftp_proxy=$1
  sudo sed --follow-symlinks -i -e "/proxy/d" /etc/nixos/configuration.nix
  sudo sed --follow-symlinks -i -e "\$i\ \ nix\.proxy \= \""$1"\"\;" /etc/nixos/configuration.nix
  sudo -E nix-build -I nixpkgs=$NIXPKGS_REPO -A system "<nixpkgs/nixos>" --option use-binary-caches false
  updateSystem --option use-binary-caches false
  export NIX_REMOTE="daemon"
}
