# macOS configuration

Targets Sequoia 15 and Tahoe 26. Build success does not guarantee every preference takes effect.

From the repository root:

```sh
just nix-check # Validate and build
just nix-up    # Apply
```

To build with new, untracked Nix files:
`nix build "path:$PWD/nix#darwinConfigurations.wax.system" --no-link`.

## Manual setup

- **Screen lock:** System Settings → Lock Screen → Require password → **Immediately**.
  Verify authentication is required after display sleep; Nix does not enforce this.
- **Spotlight:** Add unwanted folders (e.g. `~/src`, caches) through **Search Privacy**.
  `.metadata_never_index` files are not reliable folder exclusions.
- **Ice:** Keep stable; check [release compatibility](https://github.com/jordanbaird/Ice/releases)
  before upgrading to Tahoe. OS and Homebrew upgrades are not automated here.

## Notes

- Screenshots save to `~/Downloads`; third-party screenshot apps have separate settings.
- Hotkey updates preserve unrelated shortcuts. AeroSpace owns window tiling.
- Log out after Spaces changes; restart affected apps to refresh cached preferences.
