NIX cheatsheet
===============


# NIX-ENV

## For a query :
nix-env -f '<nixpkgs>' -qaPs --description ".*htop.*"

## For debug purpose :
nix-env -f '<nixpkgs>' -qaPs --description ".*vim.*" --show-trace --verbose

## For an install
nix-env '<nixpkgs>' -i -A ctags

## List all generations of nix present :
nix-env --list-generations

## Delete all generations except the last
nix-env --delete-generations old

## Delete generation #9
nix-env --delete-generations 9

## Same for nixos generations :
nix-env -p /nix/var/nix/profiles/system --list-generations

## Delete all unused packages
nix-collect-garbage

## For lauching a nix-shell of my own package called blank_env
## Don't forget to had the package derivations in ~/.nixpkgs/config.nix
nix-shell '<nixpkgs>' -A blank_env
typeset -f genericBuild | grep 'phases='
eval 'unpackPhase'
eval 'patchPhase'
eval 'configurePhase'

## eval : Evaluate several commands/arguments



## Packages installed with nixpkgs :
nix-env -f '<nixpkgs>' -i tigervnc-git-20150504  # VNC client
nix-env -f '<nixpkgs>' -i nix-prefetch-scripts   # Nix scripts for fetching from internet packages
nix-env -f '<nixpkgs>' -iA wget

## Spack :

## For debug purpose :
spack --debug install -v xfconf

## Easiest way to use python modules :
nix-shell -p python27Packages.matplotlib python27Packages.scipy


## Mains packages installed :
nix-env -f '<nixpkgs>' -i python27Packages.matplotlib
nix-env -f '<nixpkgs>' -i matplotlib
nix-env -f '<nixpkgs>' -i python2.7-scipy-0.15.1
nix-env -f '<nixpkgs>' -i -A imagemagick
nix-env -f '<nixpkgs>' -i -A xfontsel
nix-env -f '<nixpkgs>' -i -A powerline-fonts
