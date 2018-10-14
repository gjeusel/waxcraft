{pkgs}:
let
  python = import ./requirements.nix { inherit pkgs; };
in python.mkDerivation {
  name = "dash-0.19";
  src = ./.;
  buildInputs = [
  ];
  propagatedBuildInputs = [
  ];
}

