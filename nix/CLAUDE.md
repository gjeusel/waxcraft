# Nix-darwin configuration

The flake targets `aarch64-darwin` and exports `darwinConfigurations.wax` and `darwinPackages`.
Run commands from the repository root with `./nix`, or use the `just nix-*` recipes.

## Where changes belong

| Task | File / guidance |
| --- | --- |
| CLI tools, formatters, LSPs | `pkgs.nix`, usually `environment.systemPackages` |
| Package version overrides | `overlays.nix`; see below |
| GUI apps needing Login Items/launchd, or unavailable in nixpkgs | `homebrew.nix` casks |
| Homebrew services and App Store exclusives | `homebrew.nix` brews / `masApps` |
| macOS defaults | `preferences.nix`; see [README.md](README.md) for manual settings and OS caveats |
| File associations and user activation | `system-scripts.nix` |
| Keyboard remapping | `keymaps.nix` |
| PostgreSQL service and initialization | `postgres.nix` |
| Inputs, imports, fonts, platform | `flake.nix` |

Nix management is delegated to Determinate (`nix.enable = false`). Homebrew taps are flake-pinned and
immutable. Keep the nixpkgs and nix-darwin release branches in sync; `system.stateVersion` is a
compatibility setting, not a release number to bump during upgrades.

## Package versions

Check the pinned `nixpkgs-unstable` input before writing a source override. If it already contains the
requested version, overlay that package directly rather than duplicating its expression with
`overrideAttrs`; this preserves the required toolchain, features, patches, and dependencies.

For an unavoidable source-level Rust override, compare the old and new nixpkgs expressions. Update
`src`, `cargoDeps` (not only `cargoHash`), features/build flags, build inputs, patches, and the toolchain
required by upstream's `rust-version`. Build the package output before the full system.

A missing package is not by itself a reason to update the lockfile: check its name and the pinned
inputs first, and keep dependency updates within the requested scope.

## Activation hazards

- `postActivation` runs as root. Per-user `defaults`, `duti`, and `xattr` operations belong in the
  existing `userActivationScript`, invoked with `launchctl asuser` and `sudo --user`.
- For file associations, use the existing `set_handler` helper with `${pkgs.duti}/bin/duti`. Keep each
  extension in a single handler list to avoid repeated macOS prompts. Obtain bundle IDs with
  `osascript -e 'id of app "AppName"'`.
- Homebrew's `onActivation.cleanup = "zap"` removes manually installed brews/casks absent from the
  configuration. A successful build does not authorize activation.
- PostgreSQL uses nix-darwin plus an idempotent `postgresql-init` launchd agent to reconcile users,
  databases, and extensions; it is not the Homebrew PostgreSQL service.

## Validation

`just nix-check` evaluates and builds without switching. For new, untracked Nix files, use
`nix build "path:$PWD/nix#darwinConfigurations.wax.system" --no-link` so they are included without
staging them. `just nix-up` applies the configuration; use it only when application is requested.
