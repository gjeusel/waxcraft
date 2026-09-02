justfile_dir := justfile_directory()
dotfiles_dir := justfile_dir / "dotfiles"
stow_options := "--verbose --no-folding --dir " + dotfiles_dir + " --target ~/"
agents_stow_options := "--verbose --dir " + dotfiles_dir + " --target ~/"
agents_skills_dir := dotfiles_dir / "agents/.agents/skills"

# List all the just commands
default:
    @just --list

# Run all checks
check: nix-check nvim-check zsh-check nu-check

# Evaluate and build the system without switching (safe pre-flight for `just nix-up`)
[group('nix')]
nix-check:
    nix flake check {{ justfile_dir }}/nix
    nix build {{ justfile_dir }}/nix#darwinConfigurations.wax.system --no-link

# Run darwin-rebuild and switch
[group('nix')]
nix-up:
    sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --impure --flake {{ justfile_dir }}/nix#wax
    just pi-install

# List all generations of the system profile
[group('nix')]
nix-history:
    nix profile history --profile /nix/var/nix/profiles/system

# remove all generations older than 7 days

# on darwin, you may need to switch to root user to run this command
[confirm]
[group('nix')]
nix-clean:
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Garbage collect all unused nix store entries
[confirm]
[group('nix')]
nix-gc:
    # garbage collect all unused nix store entries(system-wide)
    sudo nix-collect-garbage --delete-older-than 7d
    # garbage collect all unused nix store entries(for the user - home-manager)
    # https://github.com/NixOS/nix/issues/8508
    nix-collect-garbage --delete-older-than 7d

# Show all the auto gc roots in the nix store
[group('nix')]
nix-gcroot:
    ls -al /nix/var/nix/gcroots/auto/

# Junk that tools drop inside stow packages; trashed before stowing so it never
# gets symlinked into ~. The claude package's own top-level `.claude` dir is kept.
stow_junk_patterns := ".claude .ruff_cache .DS_Store"

pi_extensions_dir := dotfiles_dir / "pi/.pi/agent/extensions"
pi_python_dir := pi_extensions_dir / "python-code"
pi_patch_script := dotfiles_dir / "pi/.pi/agent/patches/apply.sh"
pi_node_package := "path:" + justfile_dir + "/nix#darwinPackages.nodejs_22"

# Install and configure Pi dependencies and dotfiles.
[group('pi')]
pi-install:
    nix shell {{ pi_node_package }} --command npm --prefix {{ pi_extensions_dir }} ci
    nix shell {{ pi_node_package }} --command npm --prefix {{ pi_python_dir }} ci
    for legacy in "$HOME/.pi/agent/permissions.json" "$HOME/.pi/agent/extensions/permissions" "$HOME/.pi/agent/extensions/safe-trash"; do if test -e "$legacy" || test -L "$legacy"; then trash "$legacy"; fi; done
    stow {{ stow_options }} --restow pi
    test -x "$HOME/.local/bin/pi"
    PATH="$HOME/.local/bin:$PATH"; export PATH; pi update --extensions
    nix shell {{ pi_node_package }} --command {{ pi_patch_script }}
    PATH="$HOME/.local/bin:$PATH"; export PATH; test "$(command -v pi)" = "$HOME/.local/bin/pi"
    @resolved_pi="$(command -v pi 2>/dev/null || true)"; if test "$resolved_pi" != "$HOME/.local/bin/pi"; then echo "warning: this shell resolves pi to ${resolved_pi:-nothing}; run 'export PATH=\"\$HOME/.local/bin:\$PATH\"; rehash'" >&2; fi
    @echo "Pi launcher ready at ~/.local/bin/pi"

# Symlink all dotfiles.
[group('stow')]
stow-install:
    for pat in {{ stow_junk_patterns }}; do find {{ dotfiles_dir }} -mindepth 2 -name "$pat" -not -path "{{ dotfiles_dir }}/claude/.claude" -prune -exec trash {} +; done
    stow {{ stow_options }} --delete $(ls {{ dotfiles_dir }})
    # Codex follows symlinked skill directories but ignores symlinked SKILL.md files, so install agents without --no-folding.
    for package_dir in {{ dotfiles_dir }}/*; do package="${package_dir##*/}"; if test "$package" != agents; then stow {{ stow_options }} --adopt "$package"; fi; done
    for skill_dir in {{ agents_skills_dir }}/*; do skill="${skill_dir##*/}"; target="$HOME/.agents/skills/$skill"; if test -d "$target" && test ! -L "$target"; then if test -n "$(ls -A "$target")"; then echo "refusing to replace non-empty skill directory: $target" >&2; exit 1; fi; trash "$target"; fi; done
    stow {{ agents_stow_options }} --adopt agents

# Remove Stow symlinks
[group('stow')]
stow-uninstall:
    stow {{ stow_options }} --delete $(ls {{ dotfiles_dir }})

# Check zsh config: syntax check every file + interactive startup smoke test
[group('zsh')]
zsh-check:
    for f in {{ justfile_dir }}/zsh/*.zsh {{ justfile_dir }}/zsh/functions/*; do zsh -n "$f" || exit 1; done
    zsh -i -c 'echo "zsh config loaded OK"'

# Check Nushell config: load the environment and interactive configuration
[group('nushell')]
nu-check:
    nix shell {{ justfile_dir }}/nix#darwinPackages.nushell --command nu --no-history --env-config {{ dotfiles_dir }}/nushell/.config/nushell/env.nu --config {{ dotfiles_dir }}/nushell/.config/nushell/config.nu --commands 'print "Nushell config loaded OK"'

# Check nvim config: formatting + headless load smoke test
[group('nvim')]
nvim-check:
    stylua --check {{ justfile_dir }}/nvim/
    nvim --headless +'lua print("config loaded OK")' +qa!
