{
  config,
  pkgs,
  pkgs-unstable,
  pkgs-outdated,
  googleworkspace-cli,
  ...
}: {
  # Environment variables for building software with nix-provided libs (e.g. neovim)
  environment.variables = {
    CMAKE_INCLUDE_PATH = "${pkgs.gettext}/include:${pkgs.libiconv}/include";
    CMAKE_LIBRARY_PATH = "${pkgs.gettext}/lib:${pkgs.libiconv}/lib";
    CMAKE_PREFIX_PATH = "${pkgs.gettext}:${pkgs.libiconv}";
  };
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    # ----- MVD: Minimal Viable dev -----
    # ghostty # broken for now
    iterm2
    neovim
    tree-sitter

    tmux
    # TODO: Investiguate how to configure entirely tmux with nix
    #       For now, `cd ~/.tmux/plugins/tmux-thumbs &&  cargo build --release`
    # tmuxPlugins.tmux-thumbs
    tmuxp

    stow
    ripgrep
    silver-searcher
    fzf
    television
    fd
    jq
    htop
    rclone
    tealdeer
    wget
    difftastic
    bat
    dust
    zoxide
    just
    httpie
    tree
    gh
    glab
    jujutsu
    parallel

    python314Packages.watchfiles
    pkgs-unstable.python314Packages.pydantic-monty
    unixtools.watch

    yaak # postman replacement

    # ----- setup -----
    duti # help to switch default app handler for macos

    # ----- code -----
    go
    rustup

    # js
    nodejs # includes npm
    pnpm_10
    ni # Use the right package manager (npm / pnpm / bun)

    prek
    gitleaks

    # python
    uv
    # The nixpkgs wrapper renames the real executable to `.mamba-wrapped`, but Mamba's shell hook requires the executable basename to be `mamba`.
    (pkgs.runCommand "mamba-cpp-unwrapped-${pkgs-unstable.mamba-cpp.version}" {} ''
      mkdir -p "$out/bin"
      cp ${pkgs-unstable.mamba-cpp}/bin/.mamba-wrapped "$out/bin/mamba"
      chmod +x "$out/bin/mamba"
    '')
    pixi

    # Note: we install python on system instead of relying on uv for having GNU readline
    # see https://github.com/astral-sh/uv/issues/11039 & https://gregoryszorc.com/docs/python-build-standalone/main/quirks.html
    pkgs-outdated.python310
    python311
    python312
    python313

    graphviz

    # pdf
    poppler
    poppler-utils

    ghostscript # (compress pdf)
    imagemagick # imagemagick (compress pdf)

    fontconfig

    qpdf

    tesseract4
    # # tesseract4.tessdata.eng
    # # tesseract4.tessdata.fra
    # # Add more languages as needed
    # #   # Environment variables to help Tesseract find the data
    # #   TESSDATA_PREFIX = "${pkgs.tesseract4}/share/tessdata";

    # ----- infra -----
    sops
    certbot

    # kubectl
    # krew
    # kubectl-tree
    # kubectl-view-secret
    # kubectx

    (wrapHelm kubernetes-helm {
      plugins = [kubernetes-helmPlugins.helm-secrets];
    })
    kubetail

    scaleway-cli
    pgcli
    openssl
    nmap
    pkgs-outdated.google-cloud-sdk # cached ARM build; avoids rebuilding its Python dependency stack

    cmake

    coreutils

    pngquant # png compression
    jbig2enc # jpeg compression
    # ----- build nvim from sources -----
    ninja
    gettext # required for msgfmt
    libiconv # required for libintl
    curl

    # ----- vim formatters for conform -----
    alejandra
    djhtml
    eslint_d
    prettier
    prettierd
    python314Packages.sqlfmt
    stylua
    taplo
    xmlformat
    sqruff
    sql-formatter
    pgformatter

    pkgs-unstable.oxfmt
    pkgs-unstable.oxlint

    # ----- daily life -----
    # spotify # https://github.com/NixOS/nixpkgs/issues/465676
    zoom-us # video conferencing application
    discord

    # NOTE: Once launchd is fixed on Sequoia, we might define them from nixpkgs.
    #       See: https://github.com/nix-darwin/nix-darwin/issues/1255
    #       For now, if we want them in Login Items, we need to pass by brew.
    # raycast
    aerospace
    # karabiner-elements

    slack

    pkgs-unstable.bitwarden-desktop
    # bitwarden-cli

    mountain-duck

    # ----- mobile dev -----
    cocoapods

    electron

    # ----- editors -----
    vscode # because I'm altruist
    pkgs-unstable.zed-editor # neat agentic ai (unstable: stable's aarch64-darwin build isn't cached)

    protonmail-desktop

    # ----- experiments -----
    temporal
    temporal-cli
  ];
}
