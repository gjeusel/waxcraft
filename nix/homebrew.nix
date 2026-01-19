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

      "claude"

      "brave-browser" # default
      "firefox@developer-edition" # used for webdev
      "google-chrome" # used for webdev
      "tor-browser" # curiosity
      "firefox" # used for shopping
      "zen" # to try out

      "mimestream" # email

      "notion" # does not exists in nixpkgs
      "notion-calendar"

      "whatsapp"
      "signal"
      "viber" # phone calls

      "karabiner-elements" # keyboards maps
      "aldente" # set Charge Limits and Prolong Battery Lifespan
      "jordanbaird-ice" # manage the menu bar

      # "dbeaver-community" # sql UI
      "tableplus" # sql UI

      "vlc"

      "betterdisplay" # display settings
      "pika" # equivalent of ColorSlurp (get the hex code of a color)
      "obs" # screen record

      "shottr" # screenshot
      # "cleanshot" # better screenshot ?

      # "cyberghost-vpn" # VPN
      "protonvpn" # VPN
      "transmission" # torrent downloader

      "calibre" # e-book

      "modrinth" # minecraft virtual env

      "spotify"

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

      # # Mobile Dev
      # "Xcode" = 497799835;
    };
  };
}
