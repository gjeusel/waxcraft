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
- Before writing a package version override in `nix/overlays.nix`, check the pinned `nixpkgs-unstable` input. If it already contains the requested version, overlay that package directly rather than duplicating its Nix expression with `overrideAttrs`; this preserves its required toolchain, features, patches, and dependencies.
- When a source-level Rust package override is unavoidable, compare the old and new nixpkgs package expressions and update `src`, `cargoDeps` (not only `cargoHash`), cargo features/build flags, build inputs, patches, and the Rust toolchain required by upstream's `rust-version`. Build the package output before building the full system.
