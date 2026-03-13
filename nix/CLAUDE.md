# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **nix-darwin configuration** repository ("waxcraft/nix") that manages a complete macOS development environment using Nix flakes. It provides declarative configuration for system packages, Homebrew apps, system preferences, and activation scripts.

## Architecture

### Flake Structure

The main `flake.nix` serves as the entry point and imports modular configuration files:

- **flake.nix**: Defines inputs (nixpkgs, nix-darwin, nix-homebrew, homebrew taps) and outputs the `darwinConfigurations."wax"` system configuration
- **pkgs.nix**: Nix packages from nixpkgs (development tools, CLI utilities, LSPs, formatters)
- **homebrew.nix**: Homebrew brews, casks, and Mac App Store apps
- **preferences.nix**: macOS system defaults (dock, finder, NSGlobalDomain, security settings)
- **system-scripts.nix**: Activation scripts that run on system rebuild (file associations, app aliases)
- **keymaps.nix**: Keyboard remapping configuration (currently empty but available for custom mappings)
- **postgres.nix**: PostgreSQL configuration (commented out in main flake due to nix-darwin limitations)

### Key Design Decisions

1. **Nix managed by Determinate Systems**: `nix.enable = false` delegates Nix management to the "Determinate" installer
2. **Immutable Homebrew taps**: `mutableTaps = false` with flake-pinned homebrew repos
3. **User ownership**: System is configured for user "gjeusel" with `system.primaryUser`
4. **aarch64-darwin**: Platform is Apple Silicon
5. **State version 6**: Used for backwards compatibility

### Package Organization

Packages are split by installation method:

- **Nix packages** (pkgs.nix): Development tools, formatters, LSPs, some GUI apps
- **Homebrew casks** (homebrew.nix): Apps requiring launchd integration or not available in nixpkgs
- **Homebrew brews** (homebrew.nix): Services like postgresql@16, redis, meilisearch
- **Mac App Store** (homebrew.nix): Apps only available via App Store (currently just Xcode)

**Note on launchd**: Due to nix-darwin launchd issues on macOS Sequoia (see [issue #1255](https://github.com/nix-darwin/nix-darwin/issues/1255)), apps requiring Login Items (raycast, aerospace, karabiner-elements, ghostty) are installed via Homebrew instead of nixpkgs.

### File Association Management

The system uses `duti` to set default apps. To add new file associations:

1. Get app identifier: `osascript -e 'id of app "AppName"'`
2. Add to system-scripts.nix postActivation script
3. Rebuild system

## Development Workflow

### Adding a New Package

1. **Determine installation method**:
   - Prefer nixpkgs for CLI tools and development dependencies
   - Use Homebrew casks for GUI apps requiring launchd or not in nixpkgs
   - Use Homebrew brews for system services
   - Use masApps for App Store exclusives

2. **Add to appropriate file**:
   - Nix: Add to `pkgs.nix` in `environment.systemPackages`
   - Homebrew: Add to `homebrew.nix` under brews/casks/masApps


### Modifying System Preferences

1. Edit `preferences.nix` under appropriate section:
   - `system.defaults.dock`: Dock configuration
   - `system.defaults.finder`: Finder preferences
   - `system.defaults.NSGlobalDomain`: Global macOS settings
   - `system.defaults.CustomUserPreferences`: Settings not directly supported

2. For new CustomUserPreferences, reference [macos-defaults](https://github.com/yannbertrand/macos-defaults)

3. Rebuild system to apply

### Adding Activation Scripts

Activation scripts run after system rebuild. They're in `system-scripts.nix`:

- `postActivation`: Runs as user (not root) - preferred for most scripts
- `applications`: Handles app linking to /Applications

Common use cases:
- Setting file associations with duti
- Running defaults write commands
- Creating symlinks or aliases

## Important Notes

### PostgreSQL Configuration

`postgres.nix` is commented out in the main flake because nix-darwin doesn't fully support:
- `initialScript`
- `ensureDatabases`
- `ensureUsers`

See [nix-darwin#339](https://github.com/nix-darwin/nix-darwin/issues/339). PostgreSQL is currently managed via Homebrew brew (`postgresql@16`).

### Keyboard Shortcuts

Some settings must be configured manually via System Preferences:
1. Disable Ctrl+arrows for Mission Control (conflicts with Neovim)
2. Disable Caps Lock as input source switcher

### Homebrew Cleanup

`onActivation.cleanup = "zap"` removes manually installed brews/casks not in configuration. Be cautious when testing new packages.

### Font Management

Nerd Fonts are installed via nixpkgs:
```nix
fonts.packages = [
  pkgs.nerd-fonts.jetbrains-mono
  pkgs.nerd-fonts.hack
];
```

### ZSH Configuration

ZSH is configured with `enableGlobalCompInit = false` for faster startup. This requires defining an empty `compdef` in `interactiveShellInit` to avoid error messages.

## Troubleshooting

### Build Failures

1. Check flake syntax: `nix flake check`
2. Verify all imported files exist
3. Check for missing closing braces or semicolons
4. Look for undefined packages: `nix search nixpkgs <package>`

### Package Not Found

1. Update nixpkgs: `nix flake update nixpkgs`
2. Check package name: `nix search nixpkgs <partial-name>`
3. Consider Homebrew alternative if unavailable in nixpkgs

### Permission Issues

1. Ensure duti commands in system-scripts.nix use full package path
2. Check that postActivation scripts run as user, not root
3. Verify app identifiers are correct: `osascript -e 'id of app "Name"'`
