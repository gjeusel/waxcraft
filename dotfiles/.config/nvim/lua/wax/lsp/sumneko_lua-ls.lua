return {
  init_options = { documentFormatting = false }, -- done by stylua
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
        maxPreload = 3000,
      },
      telemetry = { enable = false },
    },
  },
}
