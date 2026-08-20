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
      # "postgresql@16" # can be managed via nix-darwin (see postgres.nix)
      "redis"
      "meilisearch"
      "libomp" # openmp on macos
      "py-spy" # CLI to profile python (unavailable in nixpkgs for ARM arch)

      # "agavra/tap/tuicr" # code review TUI (unavailable in nixpkgs)

      # ----- Tools without prebuilt ARM substitutes in nixpkgs -----
      # Use Homebrew bottles/upstream binaries instead of compiling locally.
      "googleworkspace-cli"
      "hashicorp/tap/terraform"
      "ocrmypdf"
    ];
    casks = [
      "ghostty" # broken in nixpkgs
      "raycast"

      "claude" # claude app
      "chatgpt" # OpenAI's coding agent desktop app
      "macwhisper"

      "linear"

      "brave-browser" # default
      "firefox@developer-edition" # used for webdev
      "firefox" # used for shopping
      "google-chrome" # used for webdev
      "tor-browser" # curiosity
      "zen" # to try out

      "mimestream" # email
      "readdle-spark" # other email client

      "notion" # does not exists in nixpkgs
      "notion-calendar"

      "whatsapp"
      "signal"
      "viber" # phone calls
      "telegram"

      "karabiner-elements" # keyboards maps
      "aldente" # set Charge Limits and Prolong Battery Lifespan
      "jordanbaird-ice" # manage the menu bar

      # "dbeaver-community" # sql UI
      "tableplus" # sql UI

      "handy" # speech to text

      "orbstack" # docker & linux VMs

      "betterdisplay" # display settings
      "pika" # equivalent of ColorSlurp (get the hex code of a color)

      # "shottr" # screenshot
      "macshot" # screenshot

      # "cyberghost-vpn" # VPN
      "protonvpn" # VPN
      "transmission" # torrent downloader

      "modrinth" # minecraft virtual env

      "spotify"
      "ytmdesktop-youtube-music"

      # ----- Tools without prebuilt ARM substitutes in nixpkgs -----
      "calibre" # e-book
      "obs" # screen record
      "vlc"

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
