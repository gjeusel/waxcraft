{
  config,
  lib,
  pkgs,
  ...
}: let
  userHome = "/Users/${config.system.primaryUser}";
  # IDs checked in Sequoia's KeyboardSettings.appex/Contents/Resources:
  # en_GB.lproj/DefaultShortcutsTable.xml and DefaultSpacesShortcuts.xml.
  # Unlisted shortcuts and existing key combinations are preserved by the activation script.
  disabledHotkeys = [
    64 # Spotlight search (Cmd+Space)
    65 # Finder search window (Cmd+Option+Space)

    32 # Mission Control (Ctrl+Up)
    33 # Application windows (Ctrl+Down)
    34 # Mission Control, slow variant
    35 # Application windows, slow variant
    36 # Show Desktop (F11)
    37 # Show Desktop, slow variant
    79 # Previous Space (Ctrl+Left)
    80 # Previous Space, slow variant
    81 # Next Space (Ctrl+Right)
    82 # Next Space, slow variant
    118 # Switch to Desktop 1 (Ctrl+1)
    119 # Switch to Desktop 2 (Ctrl+2)
    120 # Switch to Desktop 3 (Ctrl+3)
    121 # Switch to Desktop 4 (Ctrl+4)

    60 # Previous input source (Ctrl+Space)
    61 # Next input source (Ctrl+Option+Space)
    52 # Toggle Dock hiding (Option+Cmd+D)
    53 # Decrease display brightness
    54 # Increase display brightness
    55 # Decrease display brightness, preferences counterpart
    56 # Increase display brightness, preferences counterpart

    7 # Focus menu bar (Ctrl+F2)
    8 # Focus Dock (Ctrl+F3)
    9 # Focus active/next window (Ctrl+F4)
    10 # Focus window toolbar (Ctrl+F5)
    11 # Focus floating window (Ctrl+F6)
    12 # Toggle keyboard access (Ctrl+F1)
    13 # Change how Tab moves focus (Ctrl+F7)

    15 # Toggle accessibility zoom
    17 # Zoom in
    19 # Zoom out
    21 # Invert colors (Ctrl+Option+Cmd+8)
    23 # Toggle image smoothing
    25 # Increase contrast (Ctrl+Option+Cmd+.)
    26 # Decrease contrast (Ctrl+Option+Cmd+,)

    28 # Save entire screen (Cmd+Shift+3)
    29 # Copy entire screen (Ctrl+Cmd+Shift+3)
    30 # Save selected area (Cmd+Shift+4)
    31 # Copy selected area (Ctrl+Cmd+Shift+4)
    184 # Screenshot/recording options (Cmd+Shift+5)
  ];
  symbolicHotkeys =
    builtins.listToAttrs (map (id: {
        name = toString id;
        value.enabled = false;
      })
      disabledHotkeys)
    // {
      "27" = {
        enabled = true; # Move focus to next window (Cmd+`), not Minimize
        value = {
          parameters = [96 50 1048576]; # Character, hardware keycode, Cmd modifier
          type = "standard";
        };
      };
    };
  hotkeysScript = pkgs.writeShellScript "update-symbolic-hotkeys" ''
    set -euo pipefail
    domain="$1"
    hotkeys_plist=$(/usr/bin/mktemp)
    trap '/bin/rm -f "$hotkeys_plist"' EXIT
    /usr/bin/defaults export "$domain" - > "$hotkeys_plist"
    /usr/bin/plutil -lint -s "$hotkeys_plist"

    # Refuse malformed existing settings rather than silently replacing them. PlistBuddy handles
    # creation of numeric dictionary keys, which plutil -insert interprets as array indices.
    ensure_dict() {
      local kind
      if kind=$(/usr/bin/plutil -type "$1" "$hotkeys_plist" 2>/dev/null); then
        if [ "$kind" != dictionary ]; then
          echo "Refusing to replace non-dictionary hotkey settings at $1" >&2
          return 1
        fi
      else
        /usr/libexec/PlistBuddy -c "Add :''${1//./:} dict" "$hotkeys_plist"
      fi
    }

    ensure_dict AppleSymbolicHotKeys
    hotkey_updates=()
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: settings: ''
        ensure_dict AppleSymbolicHotKeys.${id}
        before=$(/usr/bin/plutil -extract AppleSymbolicHotKeys.${id} xml1 -o - "$hotkeys_plist")
        /usr/bin/plutil -replace AppleSymbolicHotKeys.${id}.enabled -bool ${lib.boolToString settings.enabled} "$hotkeys_plist"
        ${lib.optionalString (settings ? value) ''
          ensure_dict AppleSymbolicHotKeys.${id}.value
          /usr/bin/plutil -replace AppleSymbolicHotKeys.${id}.value.parameters -json ${lib.escapeShellArg (builtins.toJSON settings.value.parameters)} "$hotkeys_plist"
          /usr/bin/plutil -replace AppleSymbolicHotKeys.${id}.value.type -string ${lib.escapeShellArg settings.value.type} "$hotkeys_plist"
        ''}
        after=$(/usr/bin/plutil -extract AppleSymbolicHotKeys.${id} xml1 -o - "$hotkeys_plist")
        if [ "$before" != "$after" ]; then
          hotkey_updates+=("${id}" "$after")
        fi
      '')
      symbolicHotkeys)}

    # Apply only managed IDs in one write, preserving other shortcuts and domain keys.
    if [ "''${#hotkey_updates[@]}" -gt 0 ]; then
      /usr/bin/defaults write "$domain" AppleSymbolicHotKeys -dict-add "''${hotkey_updates[@]}"
    fi
  '';
  userPreferencesScript = pkgs.writeShellScript "user-preferences" ''
    set -euo pipefail
    /bin/mkdir -p ${lib.escapeShellArg "${userHome}/Downloads"}
    ${hotkeysScript} com.apple.symbolichotkeys

    # This private helper is best-effort; a logout remains the fallback on future macOS releases.
    activate_settings=/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings
    if [ -x "$activate_settings" ]; then
      "$activate_settings" -u || echo "warning: Log out and back in to apply keyboard shortcuts." >&2
    else
      echo "warning: activateSettings is unavailable; log out and back in to apply shortcuts." >&2
    fi

    macos_version=$(/usr/bin/sw_vers -productVersion)
    if [ "''${macos_version%%.*}" -ge 26 ] && [ -d /Applications/Ice.app ]; then
      echo "warning: Check Ice's installed version against its Tahoe compatibility release notes." >&2
      echo "Stable Ice is retained intentionally; see nix/README.md before changing channels." >&2
    fi
  '';
in {
  # Keep normal developer networking usable while enabling the application firewall.
  networking.applicationFirewall = {
    enable = true;
    blockAllIncoming = false;
    allowSigned = true;
    allowSignedApp = true;
  };

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
        "/Applications/ChatGPT.app"
        "/Applications/Brave Browser.app"
        "/Applications/Firefox Developer Edition.app"
        "/Applications/Notion.app"
        "/Applications/Nix Apps/Slack.app"
        "/Applications/Notion Calendar.app"
        "/Applications/Nix Apps/Bitwarden.app"
        "/Applications/Mimestream.app"
        "/Applications/Spotify.app"
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
      _FXSortFoldersFirst = false; # Keep files and folders interleaved when sorting by name
      _FXEnableColumnAutoSizing = true; # Fit filenames in the preferred column view
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf"; # Search the current folder by default
      AppleShowAllExtensions = true; # show all file extensions
      FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
      QuitMenuItem = true; # enable quit menu item
      ShowPathbar = true; # show path bar
      ShowStatusBar = true; # show status bar
    };

    WindowManager = {
      GloballyEnabled = false; # AeroSpace manages windows instead of Stage Manager
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
      EnableStandardClickToShowDesktop = false; # Only in Stage Manager, which is disabled
      StandardHideDesktopIcons = false;
      HideDesktop = false; # Also show desktop items if Stage Manager is enabled manually
    };

    hitoolbox.AppleFnUsageType = "Do Nothing";
    trackpad = {
      Clicking = false;
      TrackpadThreeFingerDrag = false;
    };
    # Leave power.sleep unset to preserve separate battery and AC sleep timings.
    ActivityMonitor = {
      ShowCategory = 100; # All Processes
      OpenMainWindow = true;
    };
    screencapture = {
      location = "${userHome}/Downloads";
      type = "png";
      disable-shadow = true;
    };

    # customize namespace global domain
    NSGlobalDomain = {
      "com.apple.sound.beep.feedback" = 0; # disable beep sound when pressing volume up/down key

      # If you press and hold certain keyboard keys when in a text area, the key's character begins to repeat.
      # This is very useful for vim users, they use `hjkl` to move cursor.
      # sets how long it takes before it starts repeating.
      InitialKeyRepeat = 15; # Approximately 225 ms before repeating
      # sets how fast it repeats once it starts.
      KeyRepeat = 2; # Approximately 30 ms between repeats

      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleTemperatureUnit = "Celsius";
      AppleShowScrollBars = "Automatic";
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      ApplePressAndHoldEnabled = true; # Preserve the accent picker for French typing
      AppleKeyboardUIMode = 2; # Keyboard navigation on Sonoma and later
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      AppleICUForce24HourTime = true;
      NSWindowResizeTime = 0.01; # Applicable AppKit resize animations, not all system animations
    };

    # customize settings that not supported by nix-darwin directly
    # Incomplete list of macOS `defaults` commands :
    #   https://github.com/yannbertrand/macos-defaults
    CustomUserPreferences = {
      # Symbolic hotkeys are merged during user activation, not written as a whole dictionary here.
      "com.apple.finder".DisableAllAnimations = true;
      "com.apple.desktopservices" = {
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
      "com.mimestream.Mimestream" = {
        DeleteKeyAction = "archive";
        ListStyle = "compact";
        MarkReadBehavior = "afterDelay";
        MarkReadDelay = 2;
        BlockRemoteImages = true;
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
        heatProtectMode = 1;
        sailingMode = 0;
      };
      "com.apple.ActivityMonitor".DisplayType = 0; # CPU tab (no typed nix-darwin option)
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
    };
  };

  # Spotlight folder exclusions belong in Search Privacy; marker files are unreliable on modern
  # macOS. See nix/README.md for the migration checklist. Do not rename app-managed directories.
  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u -- ${lib.escapeShellArg config.system.primaryUser})" sudo --user=${lib.escapeShellArg config.system.primaryUser} -- ${userPreferencesScript}
  '';
}
