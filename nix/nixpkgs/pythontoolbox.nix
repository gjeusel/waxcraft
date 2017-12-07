# Install it with:
# nix-enf -if pythontoolbox.nix
with import /etc/nixpkgs {};

python.buildEnv.override {
    extraLibs =[
      # Python Common Tools:
      pkgs.pythonPackages.configparser # parsing ini files
      pkgs.pythonPackages.ipdb # Debugger library
      pkgs.pythonPackages.ipython # Ipython library
      pkgs.pythonPackages.click # Create beautiful command line interfaces in Python
      pkgs.pythonPackages.six # for smoothing over the differences between the Python versions
      pkgs.pythonPackages.xmltodict # xml to dict
      pkgs.pythonPackages.autopep8 # auto format with pep8
      pkgs.pythonPackages.jedi # python completion for vim
      pkgs.pythonPackages.pathlib # handle path

      # Test:
      pkgs.pythonPackages.pytest
      pkgs.pythonPackages.betamax
      pkgs.pythonPackages.responses
      pkgs.pythonPackages.pytestpep8
      pkgs.pythonPackages.pytestflakes

      # Documentaion:
      pkgs.pythonPackages.sphinx_1_2
      pkgs.pythonPackages.sphinx_rtd_theme

      # Database handle:
      pkgs.pythonPackages.marshmallow-sqlalchemy

      # ML:
      pkgs.pythonPackages.pandas
    ];
    ignoreCollisions = true;
    }

