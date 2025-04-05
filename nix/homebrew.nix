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

      "brave-browser"
      "firefox"
      "tor-browser"
      "vlc"

      "readdle-spark" # Spark email

      "notion" # does not exists in nixpkgs
      "notion-calendar"

      "whatsapp"

      # NOTE: remove from brew once launchd is fixed
      "raycast"
      "nikitabobko/tap/aerospace" # NOTE: can safely ignore the printed error on re-run
      "karabiner-elements"

      "obs" # screen record

      "cyberghost-vpn" # VPN
      "transmission" # torrent downloader

      "calibre" # e-book

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
