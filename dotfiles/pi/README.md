# pi

Personal [Pi](https://pi.dev) configuration, stowed to `~/.pi/agent/`.

## Setup

Run this **before the first Pi launch** so `stow --adopt` cannot replace the tracked configuration with files created by Pi:

```bash
cd ~/src/waxcraft
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
just pi-extensions-install
just stow-install
pi
```

Then, inside Pi:

```text
/login
/model
```

Pi installs the packages from `settings.json` on first launch. For the Claude bridge:

```bash
claude auth login
claude auth status
```

## Extensions

```text
extensions/
├── gitleaks-guard/         scan and redact secrets
├── pane-focus/             dim unfocused panes
├── peek-document/          read PDF and Office files
├── per-model-prompt/       model-specific directives
├── permissions/            deny dangerous operations
├── pi-builtin-adjustments/ quieter built-ins
├── python-code/            sandboxed Python
├── rant/                   log preventable failures
├── safe-trash/             recoverable file deletion
├── statusbar/              minimal one-line footer
├── subagent/               subagent configuration
├── unified-edit/           flexible patch editing
└── whimsical/              playful working messages
```

## Maintenance

```bash
cd ~/src/waxcraft
just pi-extensions-install
(cd dotfiles/pi/.pi/agent/extensions && npm test)
pi update --all
```

After editing configuration or extensions, run `/reload` inside Pi.
