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
      show-recents = false; # do not show recent apps in dock
      persistent-apps = [
        # "${pkgs.ghostty}/Applications/Ghostty.app" # if coming from nixkpgs
        "/Applications/Ghostty.app"
        "/Applications/Brave Browser.app"
        "/Applications/Notion.app"
        "/Applications/Slack.app"
        "/Applications/Spark Desktop.app"
        "/Applications/Notion Calendar.app"
        "/Applications/Bitwarden.app"
        "/Applications/Mimestream.app"
      ];
      wvous-tl-corner = null; # top-left
      wvous-tr-corner = null; # top-right
      wvous-bl-corner = null; # bottom-left
      wvous-br-corner = null; # bottom-right
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
    };
  };
}
