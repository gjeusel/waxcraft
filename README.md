<p align="center"><strong>waxcraft</strong> <em>- dotfiles and notes</em></p>

---

### 1. Summary

- Text editor: [Neovim](https://neovim.io/)
- Terminal Multiplexer: [tmux](https://github.com/tmux/tmux) and [tmuxp](https://github.com/tmux-python/tmuxp)
- Shell: zsh with [zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Package Manager: Nix [Determinate](https://github.com/DeterminateSystems/nix-installer) & [Darwin](https://github.com/nix-darwin/nix-darwin)

### 2. NVIM standout plugins

- [lazy.nvim](https://github.com/folke/lazy.nvim): plugin manager
- [treesitter](https://github.com/nvim-treesitter/nvim-treesitter): instant code parsing for syntax highlight and more
- [fzf-lua](https://github.com/ibhagwan/fzf-lua): fuzzy find everything
- [lspconfig](https://github.com/neovim/nvim-lspconfig): configure builtin nvim LSP
- [mason](https://github.com/williamboman/mason.nvim): LSP & else installer
- [tslime](https://github.com/jgdavey/tslime.vim): send anything to tmux pane from vim

### 3. Use:

- install nix determinate (fast, friendly & reliable, what to ask more ?)

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install
```

- install brew (maybe shall be done by nix using home-manager ? -> rabbit hole)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

- install the flake

```bash
nix run nix-darwin/master#darwin-rebuild -- switch --impure --flake ~/src/waxcraft/nix#wax
```

- install dotfiles

```bash
stow --verbose --no-folding --dir ~/src/waxcraft/dotfiles/ --target ~/ --adopt *
```

- (optional) define the ZDOTDIR in `$HOME/.zshenv`:

```zsh
# NOTE: Overwriting this variable makes zsh search `.zshrc` inside this folder.
export ZDOTDIR=$HOME/.config/zsh
```

- add sourcing of init.zsh in your `${ZDOTDIR:-$HOME}/.zshrc`

```zsh
# init.sh file sourcing:
source $HOME/src/waxcraft/zsh/init.zsh
```
