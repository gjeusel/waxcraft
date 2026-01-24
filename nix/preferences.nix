{
  config,
  pkgs,
  ...
}: {
  # Use Touch ID for sudo
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true;
  };

  programs.zsh = {
    enable = true;
    # Speed up zsh load time (https://github.com/nix-community/home-manager/issues/3965)
    enableGlobalCompInit = false; # is the same value as enableCompletion by default
    interactiveShellInit = ''
      # define an empty compdef to avoid err messages on disabled global compinit
      compdef() { : }
    '';
  };

  system.defaults = {
    menuExtraClock.Show24Hour = true; # show 24 hour clock
    loginwindow.GuestEnabled = false; # disable guest login

    # customize dock
    dock = {
      mru-spaces = false; # do not automatically rearrange spaces based on most recent use.
      expose-group-apps = true; # Group windows by application (aerospace mission control fix else small windows)
      expose-animation-duration = 0.1; # speed of mission control animation
      autohide = true; # automatically hide and show the dock
      autohide-delay = 0.1; # delay before autohiding the dock
      autohide-time-modifier = 0.1; # time modifier for autohide
      magnification = true; # magnify the dock
      tilesize = 38;
      largesize = 42; # subtle magnification (tilesize is 38)
      show-recents = false; # do not show recent apps in dock
      persistent-apps = [
        # "${pkgs.ghostty}/Applications/Ghostty.app" # if coming from nixkpgs
        "/Applications/Ghostty.app"
        "/Applications/Brave Browser.app"
        "/Applications/Notion.app"
        "/Applications/Nix Apps/Slack.app"
        "/Applications/Notion Calendar.app"
        "/Applications/Nix Apps/Bitwarden.app"
        "/Applications/Mimestream.app"
        "/Applications/Claude.app"
        "/Applications/Spotify.app"
        "/Applications/YouTube Music Desktop App.app"
        "/Applications/WhatsApp.app"
      ];
      # Disable all hot corners (1 = no action)
      wvous-tl-corner = 1; # top-left
      wvous-tr-corner = 1; # top-right
      wvous-bl-corner = 1; # bottom-left
      wvous-br-corner = 1; # bottom-right
    };

    # customize spaces
    spaces = {
      spans-displays = true; # set "Displays have separate Spaces" to false (better aerospace perfs and behaviour)
    };

    # customize finder
    finder = {
      NewWindowTarget = "Home"; # default shown folder
      FXPreferredViewStyle = "clmv"; # prefer column view by default on finder
      _FXShowPosixPathInTitle = true; # show full path in finder title
      _FXSortFoldersFirst = false; # show folders first in order
      AppleShowAllExtensions = true; # show all file extensions
      FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
      QuitMenuItem = true; # enable quit menu item
      ShowPathbar = true; # show path bar
      ShowStatusBar = true; # show status bar
    };

    # customize namespace global domain
    NSGlobalDomain = {
      "com.apple.sound.beep.feedback" = 0; # disable beep sound when pressing volume up/down key

      # If you press and hold certain keyboard keys when in a text area, the key's character begins to repeat.
      # This is very useful for vim users, they use `hjkl` to move cursor.
      # sets how long it takes before it starts repeating.
      InitialKeyRepeat = 10; # fastest (150 ms), normal minimum is 15 (225 ms)
      # sets how fast it repeats once it starts.
      KeyRepeat = 1; # fastest (15 ms), normal minimum is 2 (30 ms)

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
      # Disable macOS keyboard shortcuts (Spotlight, Mission Control, etc.)
      # These conflict with Raycast, neovim, and terminal apps
      # Reference: https://web.archive.org/web/20141112224103/http://hintsforums.macworld.com/showthread.php?t=114785
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # Disable Spotlight shortcuts (using Raycast instead)
          "64" = { enabled = false; }; # Show Spotlight search (Cmd+Space)
          "65" = { enabled = false; }; # Show Finder search window (Cmd+Option+Space)

          # Disable all Mission Control shortcuts (conflicts with neovim/terminal)
          "32" = { enabled = false; }; # Mission Control (Ctrl+Up)
          "33" = { enabled = false; }; # Application windows (Ctrl+Down)
          "34" = { enabled = false; }; # Move left a space (Ctrl+Left)
          "35" = { enabled = false; }; # Move right a space (Ctrl+Right)
          "36" = { enabled = false; }; # Show Desktop (F11)
          "37" = { enabled = false; }; # Show Dashboard (F12)
          "62" = { enabled = false; }; # Show Dashboard (alternative)
          "79" = { enabled = false; }; # Move window to space on left (Ctrl+Shift+Left)
          "80" = { enabled = false; }; # Move window to space on right (Ctrl+Shift+Right)
          "81" = { enabled = false; }; # Move window to Desktop 1
          "82" = { enabled = false; }; # Move window to Desktop 2

          # Disable Switch to Desktop shortcuts (Ctrl+1/2/3/4)
          "118" = { enabled = false; }; # Switch to Desktop 1
          "119" = { enabled = false; }; # Switch to Desktop 2
          "120" = { enabled = false; }; # Switch to Desktop 3
          "121" = { enabled = false; }; # Switch to Desktop 4

          # Disable Input Source shortcuts (conflicts with IDE/terminal shortcuts)
          "60" = { enabled = false; }; # Select previous input source (Ctrl+Space)
          "61" = { enabled = false; }; # Select next input source (Ctrl+Option+Space)

          # Disable Dock shortcuts
          "27" = { enabled = false; }; # Minimize window (Cmd+M)
          "52" = { enabled = false; }; # Turn Dock Hiding On/Off (Opt+Cmd+D)

          # Disable display brightness shortcuts
          "53" = { enabled = false; }; # Decrease display brightness
          "54" = { enabled = false; }; # Increase display brightness
          "55" = { enabled = false; }; # Decrease display brightness (slow)
          "56" = { enabled = false; }; # Increase display brightness (slow)

          # Disable "Move focus to..." shortcuts (conflicts with terminal/IDE)
          "7" = { enabled = false; };  # Move focus to menu bar (Ctrl+F2)
          "8" = { enabled = false; };  # Move focus to Dock (Ctrl+F3)
          "9" = { enabled = false; };  # Move focus to active/next window (Ctrl+F4)
          "10" = { enabled = false; }; # Move focus to window toolbar (Ctrl+F5)
          "11" = { enabled = false; }; # Move focus to floating window (Ctrl+F6)
          "12" = { enabled = false; }; # Turn keyboard access on/off (Ctrl+F1)
          "13" = { enabled = false; }; # Change way Tab moves focus (Ctrl+F7)

          # Disable Accessibility shortcuts
          "15" = { enabled = false; }; # Turn zoom on/off
          "17" = { enabled = false; }; # Zoom in
          "19" = { enabled = false; }; # Zoom out
          "21" = { enabled = false; }; # Invert colors (Ctrl+Opt+Cmd+8)
          "23" = { enabled = false; }; # Turn image smoothing on/off
          "25" = { enabled = false; }; # Increase Contrast (Ctrl+Opt+Cmd+.)
          "26" = { enabled = false; }; # Decrease Contrast (Ctrl+Opt+Cmd+,)
        };
      };

      "com.apple.finder" = {
        AppleShowAllFiles = true;
        FXDefaultSearchScope = "SCcf"; # When performing a search, search the current folder by default
        DisableAllAnimations = true;
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
      "com.apple.HIToolbox" = {
        AppleFnUsageType = 0; # 0=Do Nothing, 1=Change Input Source, 2=Show Emoji & Symbols, 3=Start Dictation
      };
      "com.mimestream.Mimestream" = {
        DeleteKeyAction = "archive";
        ListStyle = "compact";
        MarkReadBehavior = "afterDelay";
        MarkReadDelay = 2;
        BlockRemoteImages = false;
        DisableTrackingPrevention = false;
        HideBadgeForDrafts = true;
        HideBadgeForSpam = true;
        AttachmentOpeningLocation = "downloadsFolder";
      };
      # Ice (Menu Bar Manager)
      "com.jordanbaird.Ice" = {
        AutoRehide = 1;
        HideApplicationMenus = 1;
        ShowOnClick = 1;
        ShowOnScroll = 1;
        ShowSectionDividers = 0;
        ShowOnHover = 0;
        RehideInterval = 15;
        UseIceBar = 0;
      };
      # AlDente Pro (Battery Management)
      "com.apphousekitchen.aldente-pro" = {
        chargeVal = 80;
        launchAtLogin = 1;
        showDockIcon = 0;
        noMenubarIcon = 0;
        automaticDischarge = 0;
        heatProtectMode = 0;
        sailingMode = 0;
      };
      # Activity Monitor
      "com.apple.ActivityMonitor" = {
        ShowCategory = 100; # All Processes
        DisplayType = 0; # CPU tab
        OpenMainWindow = 1;
      };
      # Transmission
      "org.m0k.transmission" = {
        WarningDonate = 0;
        WarningLegal = 0;
        CheckQuitDownloading = 1;
        CheckRemoveDownloading = 1;
      };
      # Calibre
      "net.kovidgoyal.calibre" = {
        NSDisabledCharacterPaletteMenuItem = 1;
        NSDisabledDictationMenuItem = 1;
      };
      # Screenshot Configuration
      "com.apple.screencapture" = {
        location = "~/Pictures/Screenshots";
        type = "png";
        disable-shadow = true;
      };
    };
  };

  # Spotlight exclusions to reduce mds_stores CPU usage
  # Includes: Electron apps, cache folders, package managers, and source code
  # Note: postActivation runs as root, so we must use absolute paths
  system.activationScripts.postActivation.text = ''
    USER_HOME="/Users/${config.system.primaryUser}"
    SPOTLIGHT_EXCLUSIONS=(
      "$USER_HOME/Library/Application Support/Notion"
      "$USER_HOME/Library/Application Support/Slack"
      "$USER_HOME/Library/Application Support/Code"
      "$USER_HOME/Library/Application Support/BraveSoftware"
      "$USER_HOME/Library/Application Support/Google/Chrome"
      "$USER_HOME/Library/Application Support/Discord"
      "$USER_HOME/Library/Caches"
      "$USER_HOME/.cargo"
      "$USER_HOME/.rustup"
      "$USER_HOME/.npm"
      "$USER_HOME/.pnpm"
      "$USER_HOME/opt/miniconda3"
      "$USER_HOME/src"
      "$USER_HOME/Library/Group Containers/G69SCX94XU.duck"
    )

    for dir in "''${SPOTLIGHT_EXCLUSIONS[@]}"; do
      if [ -d "$dir" ]; then
        # Add .metadata_never_index file to prevent Spotlight indexing
        touch "$dir/.metadata_never_index"
      fi
    done

    # Force macOS to re-read symbolic hotkeys settings immediately
    # This applies changes from CustomUserPreferences com.apple.symbolichotkeys
    # without requiring logout/restart
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
