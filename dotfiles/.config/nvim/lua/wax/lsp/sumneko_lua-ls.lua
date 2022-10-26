return {
  init_options = { documentFormatting = false }, -- done by stylua
  settings = {
    Lua = {
      telemetry = { enable = false },
      runtime = {
        version = "LuaJIT",
      },
      diagnostics = {
        globals = { "vim", "waxopts" },
        disable = {
          -- Need check nil
          "need-check-nil",
          -- This function requires 2 argument(s) but instead it is receiving 1
          "missing-parameter",
          -- Cannot assign `unknown` to `string`.
          "assign-type-mismatch",
          -- Cannot assign `unknown` to parameter `string`.
          "param-type-mismatch",
          -- This variable is defined as type `string`. Cannot convert its type to `unknown`.
          "cast-local-type",
        },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
        -- library = {
        --   [vim.fn.expand("$VIMRUNTIME/lua")] = true,
        --   [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
        -- },
        maxPreload = 3000,
      },
      -- disable certain warnings that don't concern us
      -- https://github.com/sumneko/lua-language-server/blob/master/doc/en-us/config.md
      type = {
        -- Cannot assign `string|nil` to parameter `string`.
        weakNilCheck = true,
        weakUnionCheck = true,
        -- Cannot assign `number` to parameter `integer`.
        castNumberToInteger = true,
      },
    },
  },
}
