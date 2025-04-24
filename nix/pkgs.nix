{
  config,
  pkgs,
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
    python312Packages.watchfiles

    # ----- setup -----
    duti # help to switch default app handler for macos

    # ----- code -----
    go
    rustup

    # js
    pnpm_10
    ni # Use the right package manager (npm / pnpm / bun)

    # python
    uv
    micromamba

    # pdf
    poppler
    poppler-utils
    ghostscript
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

    terraform
    scaleway-cli
    pgcli
    openssl

    google-cloud-sdk

    cmake

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
    postgres-lsp
    svelte-language-server
    tailwindcss-language-server
    terraform-ls
    vtsls
    yaml-language-server

    # ----- daily life -----
    spotify
    zoom-us # video conferencing application

    # NOTE: Once launchd is fixed on Sequoia, we might define them from nixpkgs.
    #       See: https://github.com/nix-darwin/nix-darwin/issues/1255
    #       For now, if we want them in Login Items, we need to pass by brew.
    # raycast
    # aerospace
    # karabiner-elements

    mountain-duck

    # ----- because I'm altruist -----
    vscode
    zed-editor

    # ----- not available on aarch64-darwin (yet) -----
    # calibre
    # obs-studio
    # vlc
  ];
}
