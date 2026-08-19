justfile_dir := justfile_directory()

# List all the just commands
default:
    @just --list

# Evaluate and build the system without switching (safe pre-flight for `just up`)
[group('nix')]
check:
    nix flake check {{ justfile_dir }}/nix
    nix build {{ justfile_dir }}/nix#darwinConfigurations.wax.system --no-link

# Run darwin-rebuild and switch
[group('nix')]
up:
    sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --impure --flake {{ justfile_dir }}/nix#wax

# List all generations of the system profile
[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

# remove all generations older than 7 days

# on darwin, you may need to switch to root user to run this command
[confirm]
[group('nix')]
clean:
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Garbage collect all unused nix store entries
[confirm]
[group('nix')]
gc:
    # garbage collect all unused nix store entries(system-wide)
    sudo nix-collect-garbage --delete-older-than 7d
    # garbage collect all unused nix store entries(for the user - home-manager)
    # https://github.com/NixOS/nix/issues/8508
    nix-collect-garbage --delete-older-than 7d

# Show all the auto gc roots in the nix store
[group('nix')]
gcroot:
    ls -al /nix/var/nix/gcroots/auto/

# Junk that tools drop inside stow packages; trashed before stowing so it never
# gets symlinked into ~. The claude package's own top-level `.claude` dir is kept.
stow_junk_patterns := ".claude .ruff_cache .DS_Store"

pi_extensions_dir := justfile_dir / "dotfiles/pi/.pi/agent/extensions"

# Recreate the complete Pi extension development and runtime dependency trees.
[group('dotfiles')]
pi-extensions-install:
    cd {{ pi_extensions_dir }} && npm ci
    cd {{ pi_extensions_dir }}/python-code && npm ci

# Symlink all dotfiles. Pi runtime dependencies are installed best-effort when
# missing; use `just pi-extensions-install` to force a deterministic refresh.
[group('dotfiles')]
stow-install:
    for pat in {{ stow_junk_patterns }}; do find {{ justfile_dir }}/dotfiles -mindepth 2 -name "$pat" -not -path "{{ justfile_dir }}/dotfiles/claude/.claude" -prune -exec trash {} +; done
    if test ! -f {{ pi_extensions_dir }}/python-code/node_modules/@pydantic/monty/package.json; then cd {{ pi_extensions_dir }}/python-code && npm ci || echo "warning: Pi extension runtime dependencies could not be installed; python-code will be disabled" >&2; fi
    stow --verbose --no-folding --delete --dir {{ justfile_dir }}/dotfiles/ --target ~/ $(ls {{ justfile_dir }}/dotfiles)
    stow --verbose --no-folding --dir {{ justfile_dir }}/dotfiles/ --target ~/ --adopt $(ls {{ justfile_dir }}/dotfiles)

# Remove stow symblinks
[group('dotfiles')]
stow-delete:
    stow --verbose --no-folding --dir {{ justfile_dir }}/dotfiles/ --target ~/ --delete $(ls {{ justfile_dir }}/dotfiles)

# Check zsh config: syntax check every file + interactive startup smoke test
[group('zsh')]
zsh-check:
    for f in {{ justfile_dir }}/zsh/*.zsh {{ justfile_dir }}/zsh/functions/*; do zsh -n "$f" || exit 1; done
    zsh -i -c 'echo "zsh config loaded OK"'

# Check nvim config: formatting + headless load smoke test
[group('nvim')]
nvim-check:
    stylua --check {{ justfile_dir }}/nvim/
    nvim --headless +'lua print("config loaded OK")' +qa!
