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
      "vlc"

      "notion" # does not exists in nixpkgs
      "notion-calendar"

      # NOTE: remove from brew once launchd is fixed
      "raycast"
      "nikitabobko/tap/aerospace" # NOTE: can safely ignore the printed error on re-run
      "karabiner-elements"

      "obs" # screen record

      "cyberghost-vpn" # VPN

      "calibre" # e-book
    ];
    masApps = {
      ## apps from appstore
      # to find id from cli: `mas search bitwarden`
      "TeamPaper" = 1199502670;
      "Bitwarden" = 1352778147;
      "Slack" = 803453959;
      "Bear" = 1091189122; # Markdown Notes
      # "Spark" = 1176895641; # email (not working from app store...)
    };
  };
}
