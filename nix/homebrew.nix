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
      "meilisearch"
    ];
    casks = [
      "ghostty" # broken in nixpkgs
      "raycast"

      "brave-browser" # default
      "firefox@developer-edition" # used for webdev
      "google-chrome" # used for webdev
      "tor-browser" # curiosity
      "firefox" # used for shopping (and )

      "readdle-spark" # Spark email

      "notion" # does not exists in nixpkgs
      "notion-calendar"
      # "notion-mail"

      "whatsapp"
      "signal"
      "viber" # phone calls

      "nikitabobko/tap/aerospace" # tiling window manager
      "karabiner-elements" # keyboards maps
      "betterdisplay" # register per screen settings
      "dbeaver-community" # sql UI

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
