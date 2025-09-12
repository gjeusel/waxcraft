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
      "libomp" # openmp on macos
    ];
    casks = [
      "ghostty" # broken in nixpkgs
      "raycast"

      "brave-browser" # default
      "firefox@developer-edition" # used for webdev
      "google-chrome" # used for webdev
      "tor-browser" # curiosity
      "firefox" # used for shopping

      "marta" # replacement for finder

      "mimestream" # email

      "notion" # does not exists in nixpkgs
      "notion-calendar"

      "whatsapp"
      "signal"
      "viber" # phone calls

      "karabiner-elements" # keyboards maps
      "aldente" # set Charge Limits and Prolong Battery Lifespan

      # "dbeaver-community" # sql UI
      "tableplus" # sql UI

      "vlc"

      "shottr" # screenshot
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
      # "TeamPaper" = 1199502670;

      ## the following apps where put in pkgs.nix
      # "Bear" = 1091189122; # Markdown Notes
    };
  };
}
