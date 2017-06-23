self: super:

{
  vim_configurable = super.vim_configurable.override {
    lua = self.lua;
  };
}
