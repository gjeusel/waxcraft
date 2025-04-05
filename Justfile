justfile_dir := justfile_directory()

# List all the just commands
default:
    @just --list

# Run darwin-rebuild and switch
[group('nix')]
up:
    nix run nix-darwin/master#darwin-rebuild -- switch --impure --flake {{justfile_dir}}/nix#wax

# List all generations of the system profile
[group('nix')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

# remove all generations older than 7 days

# on darwin, you may need to switch to root user to run this command
[group('nix'), confirm]
clean:
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Garbage collect all unused nix store entries
[group('nix'), confirm]
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
