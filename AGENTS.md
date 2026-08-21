# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Repository Overview

**waxcraft** is a personal dotfiles and system configuration repository for macOS (Apple Silicon). It manages:

- **Nix-darwin system configuration** - Declarative macOS environment via Nix flakes
- **Neovim configuration** - Lua-based config with lazy.nvim
- **Zsh configuration** - Shell setup with zinit plugin manager
- **Dotfiles** - Application configs managed via GNU Stow

## Repository Layout and Validation

- The Nix flake root is `nix/`, not the repository root. Use `nix flake ... ./nix` or the `just nix-*` recipes; do not run a bare `nix flake update` from the repository root.
- Pi's extension package is `dotfiles/pi/.pi/agent/extensions/`. Run its checks with `npm --prefix dotfiles/pi/.pi/agent/extensions test` (or `npm run typecheck` from that directory), not from the repository root.
- Use the package-local `tsc` through the npm script; do not use `npx tsc`, which may resolve to the unrelated placeholder package.
- `lsp_diagnostics` paths are relative to its `root`; do not prefix them with the root path a second time.
- The Pi configuration guide is `dotfiles/pi/README.md`; extension directories do not necessarily have individual manifests or READMEs, so inspect the tree before assuming either exists.
