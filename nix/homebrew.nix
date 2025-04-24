{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap"; # "zap" removes manually installed brews and casks
      autoUpdate = false; # nix-homebrew is handling homebrew updates
      upgrade = false;
    };
    brews = [
      "mas"
      "postgresql@16"
      "redis"
    ];
    casks = [
      "ghostty" # broken in nixpkgs
      "raycast"

      "brave-browser"
      "firefox"
      "tor-browser"
      "google-chrome"

      "readdle-spark" # Spark email

      "notion" # does not exists in nixpkgs
      "notion-calendar"

      "whatsapp"
      "signal"
      "viber" # phone calls

      "nikitabobko/tap/aerospace"
      "karabiner-elements"
      "dbeaver-community"

      "vlc"

      "obs" # screen record

      "cyberghost-vpn" # VPN
      "transmission" # torrent downloader

      "calibre" # e-book

      "modrinth" # minecraft virtual env

      # to lookup:
      # "gifox" # gif maker
      # "homerow" # keyboard for everything instead of pad
      # "rekordbox" # dj software
      # "ableton-live-suite" # sound editor
    ];
    masApps = {
      ## apps from appstore
      # to find id from cli: `mas search bitwarden`
      "TeamPaper" = 1199502670;
      "Bitwarden" = 1352778147;
      "Slack" = 803453959;
      "Bear" = 1091189122; # Markdown Notes
    };
  };
}
