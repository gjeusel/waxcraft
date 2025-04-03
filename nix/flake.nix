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
        neovim

        tmux
        tmuxp

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
        aerospace

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
        python312Packages.httpie
        cmake
        openssl

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
        postgres-lsp
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

      system.activationScripts = {
        # Following should allow us to disable conflicting shortcuts.
        postActivation.text = ''
          # Disable Minimize:
          defaults write -g NSUserKeyEquivalents -dict-add 'Minimize' '\0'
        '';

        # Allow Raycast/Spotlight to find apps installed via nixpkgs brew:
        applications.text = let
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
      };

      system.defaults = {
        menuExtraClock.Show24Hour = true; # show 24 hour clock
        loginwindow.GuestEnabled = false; # disable guest login

        # customize dock
        dock = {
          autohide = true; # automatically hide and show the dock
          mru-spaces = false; # do not automatically rearrange spaces based on most recent use.
          expose-group-apps = false; # Group windows by application
          tilesize = 38;
          show-recents = false; # do not show recent apps in dock
          persistent-apps = [
            # "${pkgs.ghostty}/Applications/Ghostty.app" # if coming from nixkpgs
            "/Applications/Ghostty.app"
            "/Applications/Brave Browser.app"
            "/Applications/Slack.app"
            "/Applications/Notion.app"
          ];
          wvous-tl-corner = null; # top-left
          wvous-tr-corner = null; # top-right
          wvous-bl-corner = null; # bottom-left
          wvous-br-corner = null; # bottom-right
        };

        # customize finder
        finder = {
          FXPreferredViewStyle = "clmv"; # prefer column view by default on finder
          _FXShowPosixPathInTitle = true; # show full path in finder title
          AppleShowAllExtensions = true; # show all file extensions
          FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
          QuitMenuItem = true; # enable quit menu item
          ShowPathbar = true; # show path bar
          ShowStatusBar = true; # show status bar
        };

        # customize namespace global domain
        NSGlobalDomain = {
          "com.apple.sound.beep.feedback" = 0; # disable beep sound when pressing volume up/down key

          # If you press and hold certain keyboard keys when in a text area, the key’s character begins to repeat.
          # This is very useful for vim users, they use `hjkl` to move cursor.
          # sets how long it takes before it starts repeating.
          InitialKeyRepeat = 15; # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
          # sets how fast it repeats once it starts.
          KeyRepeat = 2; # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)

          AppleMeasurementUnits = "Centimeters";
          AppleMetricUnits = 1;
          AppleTemperatureUnit = "Celsius";
          AppleShowScrollBars = "Automatic";
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          AppleICUForce24HourTime = true;
          NSWindowResizeTime = 0.01;
        };

        # customize settings that not supported by nix-darwin directly
        # Incomplete list of macOS `defaults` commands :
        #   https://github.com/yannbertrand/macos-defaults
        CustomUserPreferences = {
          # NOTE: Some options are not supported by nix-darwin directly, manually set them:
          #   1. To avoid conflicts with neovim, disable ctrl + up/down/left/right to switch spaces in:
          #     [System Preferences] -> [Keyboard] -> [Keyboard Shortcuts] -> [Mission Control]
          #   2. Disable use Caps Lock as 中/英 switch in:
          #     [System Preferences] -> [Keyboard] -> [Input Sources] -> [Edit] -> [Use 中/英 key to switch ] -> [Disable]

          "com.apple.finder" = {
            AppleShowAllFiles = true;
            _FXSortFoldersFirst = true;
            FXDefaultSearchScope = "SCcf"; # When performing a search, search the current folder by default
          };
          "com.apple.desktopservices" = {
            # Avoid creating .DS_Store files on network or USB volumes
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          "com.apple.WindowManager" = {
            EnableStandardClickToShowDesktop = 0; # Click wallpaper to reveal desktop
            StandardHideDesktopIcons = 0; # Show items on desktop
            HideDesktop = 1; # Do not hide items on desktop & stage manager
          };
          "com.apple.screensaver" = {
            # Require password immediately after sleep or screen saver begins
            askForPassword = 1;
            askForPasswordDelay = 0;
          };
          "com.apple.AdLib" = {
            allowApplePersonalizedAdvertising = false;
          };
        };
      };

      # Use Touch ID for sudo
      security.pam.services.sudo_local = {
        enable = true;
        touchIdAuth = true;
        reattach = true;
      };

      # NOTE: Some options are not supported by nix-darwin directly, manually set them:
      #   1. To avoid conflicts with neovim, disable ctrl + up/down/left/right to switch spaces in:
      #     [System Preferences] -> [Keyboard] -> [Keyboard Shortcuts] -> [Mission Control]
      #   2. Disable use Caps Lock as 中/英 switch in:
      #     [System Preferences] -> [Keyboard] -> [Input Sources] -> [Edit] -> [Use 中/英 key to switch ] -> [Disable]

      system.keyboard = {
        enableKeyMapping = true; # Required for custom key remapping
        # List of keyboard mappings to apply, for more information see:
        # https://developer.apple.com/library/content/technotes/tn2450/_index.html
        #
        # use https://hidutil-generator.netlify.app/ and convert hex to decimal
        userKeyMapping = [];
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
