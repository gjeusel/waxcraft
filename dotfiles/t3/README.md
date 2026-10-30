# T3 Code

Server and client preferences for the installed T3 Code Beta, checked on 2026-10-30.

- The Codex provider is enabled. Model, reasoning, and permission defaults are not set by these files.
- Send prompts with ⌘Enter on macOS (Ctrl+Enter elsewhere), including single-line prompts.
- Follow-up prompts steer the current turn by default.
- Idle compaction runs on return.
- Project-specific settings can override these defaults; existing threads retain their selections.

## Apply

Quit T3 Code before migrating its settings. Compare the existing
`~/.t3/userdata/settings.json` and `client-settings.json` with the tracked files and merge any additional
preferences first. Do not copy credentials or machine-specific provider paths into
the repository. Back up the existing regular file outside this package before
restowing; Stow refuses to replace it with a symlink automatically.

From the repository root, after backing up and moving the conflicting file:

```sh
stow --verbose --no-folding --dir dotfiles --target "$HOME" --restow t3
```

Reopen T3 Code and check the model, reasoning, and permissions on a new thread.
The installed version resolves symlink targets when saving settings, so later
changes in its UI can modify this tracked file. Review those diffs before committing.

Do not stow the entire userdata directory: it also contains credentials, secrets,
databases, logs, and session state. Desktop settings remain unmanaged.

## Open in Zed

The installed version stores its preferred editor under `t3code:last-editor` in
client-local storage, not in the supported JSON settings. There is no verified
dotfile setting for it in this version. In the editor dropdown, choose Zed once;
the app remembers it on that client while Zed remains available. Repeat this on
each new client. Do not add an unsupported `preferredEditor` key to settings.json.
