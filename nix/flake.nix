{
  description = "Wax Darwin Nix Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    nix-homebrew,
  }: let
    configuration = {
      pkgs,
      config,
      ...
    }: {
      # https://determinate.systems/posts/nix-darwin-updates/
      nix.enable = false; # let nix-darwin take full control over "Determinate"

      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.allowBroken = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs; [
        # ----- MVD: Minimal Viable dev -----
        # ghostty # broken for now
        tmux
        neovim

        ripgrep
        fzf
        jq
        htop
        rclone
        tldr
        wget
        bat
        dust

        raycast

        # ----- code -----
        go
        rustup

        # ----- infra -----
        sops
        kubectl
        terraform
        scaleway-cli

        # ----- vim formatters for conform -----
        alejandra
        djhtml
        eslint_d
        prettierd
        python312Packages.sqlfmt
        stylua
        taplo
        xmlformat

        # ----- daily life -----
        # calibre # unavailable for aarch64-darwin

        # ----- because I'm altruist -----
        vscode
        zed-editor
      ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
        ];
        casks = [
          "brave-browser"
          "vlc" # unavailable in nixpkgs for aarch64-darwin
          "ghostty" # broken in nixpkgs
          "notion" # does not exists in nixpkgs

          # "postgresql@16"
          # "firefox"
          # "nikitabobko/tap/aerospace"
        ];
        masApps = {
          ## apps from appstore
          # to find id from cli: `mas search bitwarden`
          "TeamPaper" = 1199502670;
          "Bitwarden" = 1352778147;
          "Slack" = 803453959;
        };
        onActivation.cleanup = "zap";
      };

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      system.defaults = {
        dock.autohide = true;
        dock.persistent-apps = [
          # "/Applications/Brave Browser.app"
          # "${pkgs.ghostty}/Applications/Ghostty.app"
          # "/Applications/Ghostty.app"
        ];

        finder.FXPreferredViewStyle = "clmv"; # prefer column view by default on finder
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.KeyRepeat = 2; # lowest minimum
      };

      # # Necessary for using flakes on this system.
      # nix.settings.experimental-features = "nix-command flakes";

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true; # default shell on catalina

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."wax" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true; # Apple Silicon Only
            user = "gjeusel"; # User owning the Homebrew prefix
            autoMigrate = true;
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."wax".pkgs;
  };
}
