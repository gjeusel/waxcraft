return {
  settings = {
    ["eslint.format.enable"] = true,
    ["eslint.experimental.useFlatConfig"] = true,
  },
  -- Done by eslint_d from conform
  -- on_attach = function(client, bufnr)
  --   vim.api.nvim_create_autocmd("BufWritePre", {
  --     buffer = bufnr,
  --     command = "EslintFixAll",
  --   })
  -- end,
}
