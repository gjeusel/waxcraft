# Nix Overlays for overriding nixpkgs package versions
#
# HOW OVERLAYS WORK:
# -----------------
# An overlay is a function: `final: prev: { ... }`
#   - `prev`: the previous/original package set (use to access original packages)
#   - `final`: the final package set after all overlays (use for dependencies)
#
# Use `prev.package.overrideAttrs` to modify an existing package's attributes
# while keeping everything else (build steps, dependencies, meta, etc.)
#
# HOW TO ADD A NEW OVERLAY:
# ------------------------
# 1. Find the package definition in nixpkgs to understand the URL pattern:
#    https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name
#
# 2. Find the new version number (check app's changelog/releases)
#
# 3. Compute the hash (check nixpkgs for fetchurl vs fetchzip):
#
#    For fetchurl (downloads file as-is, e.g. mountain-duck):
#      nix-prefetch-url --name pkg.zip "https://example.com/download-url"
#      nix hash convert --hash-algo sha256 <base32-hash>
#
#    For fetchzip (auto-extracts, e.g. aerospace):
#      nix-prefetch-url --unpack "https://example.com/download.zip"
#      nix hash convert --hash-algo sha256 <base32-hash>
#
# 4. Add the overlay below following the pattern, then rebuild: just up
#
# All overlays defined here are automatically applied via:
#   nixpkgs.overlays = builtins.attrValues (import "${self}/overlays.nix");
#
{
  mountain-duck = final: prev: {
    mountain-duck = prev.mountain-duck.overrideAttrs (old: rec {
      version = "5.1.1.28444";
      src = prev.fetchurl {
        url = "https://dist.mountainduck.io/Mountain%20Duck-${version}.zip";
        hash = "sha256-/qAQhYSG/OvCEu6BUSwENdb4KzhKiOP+hKTgrLBZER4=";
      };
    });
  };

  aerospace = final: prev: {
    aerospace = prev.aerospace.overrideAttrs (old: rec {
      version = "0.20.2-Beta";
      src = prev.fetchzip {
        url = "https://github.com/nikitabobko/AeroSpace/releases/download/v${version}/AeroSpace-v${version}.zip";
        hash = "sha256-PyWHtM38XPNkkEZ0kACPia0doR46FRpmSoNdsOhU4uw=";
      };
    });
  };
}
