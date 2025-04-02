<p align="center"><strong>waxcraft</strong> <em>- dotfiles and notes</em></p>

---

- Text editor: [Neovim](https://neovim.io/) (nightly)
- Terminal Multiplexer: [tmux](https://github.com/tmux/tmux) and [tmuxp](https://github.com/tmux-python/tmuxp)
- Shell: [zsh](https://ohmyz.sh/) with [antibody](https://github.com/getantibody/antibody) plugin manager
- Nix Darwin


### nvim standout plugins

- [packer](https://github.com/wbthomason/packer.nvim): plugin manager
- [treesitter](https://github.com/nvim-treesitter/nvim-treesitter): instant code parsing for syntax highlight and more
- [fzf-lua](https://github.com/ibhagwan/fzf-lua): fuzzy find everything
- [lspconfig](https://github.com/neovim/nvim-lspconfig): configure builtin nvim LSP
- [mason](https://github.com/williamboman/mason.nvim): LSP & else installer
- [tslime](https://github.com/jgdavey/tslime.vim): send anything to tmux pane from vim


### Notes:

#### Nix Cheatsheet
- update setup
```bash
nix run nix-darwin/master#darwin-rebuild -- switch --impure --flake ~/src/waxcraft/nix#wax
```


#### Profile zsh startup time:

- Use [zsh/zprof](https://stevenvanbael.com/profiling-zsh-startup) module
- Use `set -x` at top of zshrc to echo line by line

#### Neovim:

- [Lua Type Hint](https://github.com/LuaLS/lua-language-server/wiki/Annotations)
