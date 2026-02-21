{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    # ----- MVD: Minimal Viable dev -----
    # ghostty # broken for now
    iterm2
    neovim

    tmux
    # TODO: Investiguate how to configure entirely tmux with nix
    #       For now, `cd ~/.tmux/plugins/tmux-thumbs &&  cargo build --release`
    # tmuxPlugins.tmux-thumbs
    tmuxp

    stow
    ripgrep
    silver-searcher
    fzf
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

    python312Packages.watchfiles
    unixtools.watch

    yaak # postman replacement

    # ----- setup -----
    duti # help to switch default app handler for macos

    # ----- code -----
    go
    rustup

    # js
    pnpm_10
    ni # Use the right package manager (npm / pnpm / bun)
    typescript-language-server

    prek
    git-secrets
    gitleaks

    # python
    uv
    # micromamba # https://github.com/NixOS/nixpkgs/issues/456288
    mamba-cpp
    pyright

    # Note: we install python on system instead of relying on uv for having GNU readline
    # see https://github.com/astral-sh/uv/issues/11039 & https://gregoryszorc.com/docs/python-build-standalone/main/quirks.html
    python310
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

    # kubectl
    # krew
    # kubectl-tree
    # kubectl-view-secret
    # kubectx

    (wrapHelm kubernetes-helm {
      plugins = [kubernetes-helmPlugins.helm-secrets];
    })
    kubetail

    terraform
    scaleway-cli
    pgcli
    openssl
    nmap

    google-cloud-sdk

    cmake

    coreutils

    ghostscript # pdf compression
    pngquant # png compression
    jbig2enc # jpeg compression
    ocrmypdf # pdf compression

    # ----- build nvim from sources -----
    ninja
    cmake
    gettext
    curl

    # ----- vim formatters for conform -----
    alejandra
    djhtml
    eslint_d
    nodePackages.prettier
    prettierd
    python312Packages.sqlfmt
    stylua
    taplo
    xmlformat
    sqruff
    sql-formatter
    pgformatter

    # ----- vim LSP -----
    lua-language-server
    bash-language-server
    # eslint-lsp # not available
    helm-ls
    # html-lsp # not available
    # json-lsp # not available
    pyright
    python312Packages.python-lsp-server
    ruff
    # (ruff.overrideAttrs (old: {version = "0.9.5";}))
    rust-analyzer
    sqls
    postgres-language-server
    svelte-language-server
    tailwindcss-language-server
    terraform-ls
    vtsls
    yaml-language-server

    # ----- daily life -----
    # spotify # https://github.com/NixOS/nixpkgs/issues/465676
    zoom-us # video conferencing application
    discord

    # NOTE: Once launchd is fixed on Sequoia, we might define them from nixpkgs.
    #       See: https://github.com/nix-darwin/nix-darwin/issues/1255
    #       For now, if we want them in Login Items, we need to pass by brew.
    # raycast
    aerospace
    # pkgs-unstable.aerospace
    # karabiner-elements

    slack

    bitwarden-desktop
    # bitwarden-cli

    mountain-duck

    # ----- mobile dev -----
    cocoapods

    electron_39

    # ----- editors -----
    vscode # because I'm altruist
    zed-editor # neat agentic ai

    # ----- not available on aarch64-darwin (yet) -----
    # calibre
    # obs-studio
    # vlc

    # ----- experiments -----
    temporal
    temporal-cli
  ];
}
