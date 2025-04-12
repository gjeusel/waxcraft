return {
  settings = {
    -- https://rust-analyzer.github.io/manual.html#configuration
    -- https://raw.githubusercontent.com/rust-analyzer/rust-analyzer/master/editors/code/package.json
    ["rust-analyzer"] = {
      completion = {
        -- prevent snippets from adding () which is not "." repeatable
        callable = { snippets = "none" },
      },
      -- experimental = {
      --   procAttrMacros = false, -- Expand attribute macros.
      -- },
    },
  },
}
