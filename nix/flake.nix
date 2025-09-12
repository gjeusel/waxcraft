{
  description = "Wax Darwin Nix Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # ----- Darwin -----
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "nix-darwin";
    };

    # ----- Homebrew taps -----
    # https://github.com/zhaofengli/nix-homebrew/issues/5#issuecomment-2565926343
    # https://github.com/sonntag/nix/blob/5ae4a2a154bb2cb95e3b390524498a8867b734b4/flake.nix#L43-L46
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-services = {
      url = "github:homebrew/homebrew-services";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-darwin,
    #
    nix-homebrew,
    homebrew-core,
    homebrew-cask,
    homebrew-services,
    homebrew-bundle,
    # nikitabobko-tap,
  }: let
    user = "gjeusel";

    configuration = {
      pkgs,
      config,
      ...
    }: {
      # https://determinate.systems/posts/nix-darwin-updates/
      nix.enable = false; # let nix-darwin take full control over "Determinate"

      nixpkgs = {
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
        hostPlatform = "aarch64-darwin"; # The platform the configuration will be used on.
      };

      system.stateVersion = 6; # Used for backwards compatibility, please read the changelog before changing (> darwin-rebuild changelog).
      system.configurationRevision = self.rev or self.dirtyRev or null; # Set Git commit hash for darwin-version.

      system.primaryUser = user;

      fonts.packages = [
        # https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nerd-fonts+hack
        pkgs.nerd-fonts.jetbrains-mono
        pkgs.nerd-fonts.hack
      ];

      imports = [
        "${self}/pkgs.nix" # pkgs from nixpkgs
        "${self}/homebrew.nix" # homebrew
        "${self}/preferences.nix" # system.default
        "${self}/system-scripts.nix" # system.activationScripts
        "${self}/keymaps.nix" # system.keyboard
        #
        # "${self}/postgres.nix" # not fuly working on nix-darwin (and what of launchctl ?)
      ];
    };
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."wax" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        ({config, ...}: {
          # https://github.com/zhaofengli/nix-homebrew/issues/5
          homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
        })
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true; # Apple Silicon Only
            autoMigrate = true;
            inherit user; # User owning the Homebrew prefix
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
            };
            mutableTaps = false;
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."wax".pkgs;
  };
}
