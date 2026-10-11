# waxcraft

Personal macOS (Apple Silicon) dotfiles: Nix-darwin, Neovim/Lua, Zsh/zinit, and application configs
managed with GNU Stow.

## Task-specific guidance

- Prefer nixpkgs over Homebrew for available dependencies so the setup can be reused on Linux.
- For package or Nix changes, read [nix/AGENTS.md](nix/AGENTS.md) for package selection, Homebrew
  exceptions, overrides, and activation hazards. The flake root is `nix/`, not the repository root.
- For Pi configuration or extensions, use [dotfiles/pi/README.md](dotfiles/pi/README.md) for setup,
  package layout, and maintenance. Extension directories do not necessarily have their own manifests
  or READMEs.
- Neovim sources live in `nvim/`, reached through `dotfiles/nvim/.config/nvim`; Zsh sources live in
  `zsh/`, loaded by sourcing `zsh/init.zsh` from the user's `.zshrc` (see [README.md](README.md)).
- Repository-managed shared skills live in `dotfiles/agents/.agents/skills/`; harness-specific
  instructions live under `dotfiles/{claude,codex,pi}/`. Other installed skills may be external.
  Resolve symlinks and edit the repository source when one exists.

## Validation and application

Choose checks for the changed component, not the whole system for every edit. From the repository root:

| Component                | Check                                                   |
| ------------------------ | ------------------------------------------------------- |
| Nix                      | `just nix-check` (evaluate and build without switching) |
| Pi extensions            | `npm --prefix dotfiles/pi/.pi/agent/extensions test`    |
| Neovim                   | `just nvim-check`                                       |
| Zsh                      | `just zsh-check`                                        |
| Nushell                  | `just nu-check`                                         |
| Instructions/skills only | Check references, frontmatter, and `git diff --check`   |

The Neovim and Zsh startup smoke tests load the live user configuration, not an isolated checkout;
verify it points to the edited sources. Startup can install missing plugins. On an unconfigured
machine, use static checks (`stylua --check nvim/`, `zsh -n <changed-file>`) and report the smoke tests
as skipped rather than bootstrapping. Syntax-check changed Zsh files individually: `just zsh-check`
does not cover top-level `.sh` files or `zsh/completions/`.

For Pi typechecking alone, run `npm run typecheck` in its extension package. Use the package-local
`tsc`, not `npx tsc`, which may resolve to the unrelated placeholder package. `lsp_diagnostics` paths
are relative to its `root`.

**Stow visibility:** Existing linked-file edits affect the home-directory copy immediately. Most
packages use `--no-folding`: added, renamed, or removed individually linked files require restowing.
Changes inside directory symlinks (`nvim`, existing shared skills) are visible immediately; new skill
directories still need restowing. Keep folding enabled for `agents`: Codex discovers symlinked skill
directories, not symlinked `SKILL.md` files.

An existing file referencing a new, unlinked file can break the live configuration until restowed.
When changing file layout, report any required restow; execute it only when application is authorized.
Prefer a package-only restow without `--adopt`, for example from the repository root:

```sh
stow --verbose --no-folding --dir dotfiles --target "$HOME" --restow pi
```

`just nix-up` activates the system and installs Pi dependencies; it is not a validation command.
`just stow-install` uses `--adopt` and can overwrite tracked files with existing home-directory content.
Run application/install commands only when the user asks to apply or install the configuration.
