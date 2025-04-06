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
    tmuxp

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

    # ----- setup -----
    duti # help to switch default app handler for macos

    # ----- code -----
    go
    rustup
    uv
    pnpm_10
    ni # Use the right package manager (npm / pnpm / bun)

    # ----- infra -----
    sops
    kubectl
    (wrapHelm kubernetes-helm {
      plugins = [kubernetes-helmPlugins.helm-secrets];
    })
    terraform
    scaleway-cli
    pgcli
    openssl

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
