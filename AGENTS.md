# waxcraft

Personal macOS (Apple Silicon) dotfiles: Nix-darwin, Neovim/Lua, Zsh/zinit, and application configs
managed with GNU Stow. `CLAUDE.md` is a symlink to this file.

## Task-specific guidance

- For Nix changes, read [nix/CLAUDE.md](nix/CLAUDE.md) for package selection, overrides, and activation
  hazards. The flake root is `nix/`, not the repository root.
- For Pi configuration or extensions, use [dotfiles/pi/README.md](dotfiles/pi/README.md) for setup,
  package layout, and maintenance. Extension directories do not necessarily have their own manifests
  or READMEs.
- Shared skills live in `dotfiles/agents/.agents/skills/`; harness-specific instructions live under
  `dotfiles/{claude,codex,pi}/`. Edit repository sources rather than unrelated installed copies.

## Validation and application

Choose checks for the changed component, not the whole system for every edit. From the repository root:

| Component | Check |
| --- | --- |
| Nix | `just nix-check` (evaluate and build without switching) |
| Pi extensions | `npm --prefix dotfiles/pi/.pi/agent/extensions test` |
| Neovim | `just nvim-check` |
| Zsh | `just zsh-check` |
| Nushell | `just nu-check` |
| Instructions/skills only | Check references, frontmatter, and `git diff --check` |

For Pi typechecking alone, run `npm run typecheck` in its extension package. Use the package-local
`tsc`, not `npx tsc`, which may resolve to the unrelated placeholder package. `lsp_diagnostics` paths
are relative to its `root`.

**Stow visibility:** Most packages use `--no-folding` (`agents` is the exception). Existing linked-file
edits affect the home-directory copy immediately; added or renamed files require restowing the affected
package. An existing file referencing a new file can therefore break the live configuration until
restowed. When changing file layout, report the required restow; execute it only when application is
authorized. Prefer a package-only restow without `--adopt`, for example from the repository root:

```sh
stow --verbose --no-folding --dir dotfiles --target "$HOME" --restow pi
```

`just nix-up` activates the system and installs Pi dependencies; it is not a validation command.
`just stow-install` uses `--adopt` and can overwrite tracked files with existing home-directory content.
Run application/install commands only when the user asks to apply or install the configuration.
