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
        zoxide

        raycast

        # ----- code -----
        go
        rustup
        pnpm_10
        uv

        # ----- infra -----
        sops
        kubectl
        terraform
        scaleway-cli
        python312Packages.pgcli

        # ----- vim formatters for conform -----
        alejandra
        djhtml
        eslint_d
        prettierd
        python312Packages.sqlfmt
        stylua
        taplo
        xmlformat

        # ----- vim LSP -----
        lua-language-server
        bash-language-server
        # eslint-lsp # not available
        helm-ls
        # html-lsp # not available
        # json-lsp # not available
        pyright
        python312Packages.python-lsp-server
        ruff
        rust-analyzer
        sqls
        svelte-language-server
        tailwindcss-language-server
        terraform-ls
        vtsls
        yaml-language-server

        # ----- daily life -----
        # calibre # unavailable for aarch64-darwin
        spotify
        karabiner-elements

        # ----- because I'm altruist -----
        vscode
        zed-editor
      ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
          "postgresql@16"
          "redis"
        ];
        casks = [
          "ghostty" # broken in nixpkgs

          "brave-browser"
          "firefox"
          "vlc" # unavailable in nixpkgs for aarch64-darwin

          "notion" # does not exists in nixpkgs
          "notion-calendar"

          # "nikitabobko/tap/aerospace" # more recent than in nixpkgs (error)

          "calibre" # e-book
        ];
        masApps = {
          ## apps from appstore
          # to find id from cli: `mas search bitwarden`
          "TeamPaper" = 1199502670;
          "Bitwarden" = 1352778147;
          "Slack" = 803453959;
          # "Spark" = 1176895641; # email (not working from app store...)
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
          # "${pkgs.ghostty}/Applications/Ghostty.app" # if coming from nixkpgs
          "/Applications/Ghostty.app"
          "/Applications/Brave Browser.app"
          "/Applications/Slack.app"
          "/Applications/Notion.app"
        ];

        finder.FXPreferredViewStyle = "clmv"; # prefer column view by default on finder
        loginwindow.GuestEnabled = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.KeyRepeat = 2; # lowest minimum
        NSGlobalDomain.NSWindowResizeTime = 0.01;
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
