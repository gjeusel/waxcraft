return {
  on_attach = function(client, _)
    client.server_capabilities.colorProvider = false
    client.server_capabilities.documentHighlightProvider = false

    client.server_capabilities.documentFormattingProvider = false
  end,
  settings = {
    Lua = {
      telemetry = { enable = false },
      runtime = { version = "LuaJIT" },
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
        checkThirdParty = false, -- https://github.com/sumneko/lua-language-server/wiki/Libraries#environment-emulation
        -- Make the server aware of Neovim runtime files
        -- library = {
        --   "${3rd}/luv/library",
        --   unpack(vim.api.nvim_get_runtime_file("", true)),
        -- },
        -- maxPreload = 3000,
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
