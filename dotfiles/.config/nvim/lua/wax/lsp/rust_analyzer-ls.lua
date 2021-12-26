return {
  settings = {
    -- https://raw.githubusercontent.com/rust-analyzer/rust-analyzer/master/editors/code/package.json
    ["rust-analyzer"] = {
      experimental = {
        procAttrMacros = false, -- Expand attribute macros.
      },
    },
  },
}
