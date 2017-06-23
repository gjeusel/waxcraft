let
  pkgs = import <nixpkgs> {};
in
  import pkgs.path { overlays = [(self: super:
  {
    vim_configurable = super.vim_configurable.override {
      lua = self.lua;
    };
  }
)];
}
