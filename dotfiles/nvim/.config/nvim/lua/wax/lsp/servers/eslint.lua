local util = require("lspconfig.util")

return {
  settings = {
    ["eslint.format.enable"] = false,
    ["eslint.experimental.useFlatConfig"] = true,
  },
  on_attach = function(client, bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local root_dir = util.root_pattern("eslint.config.*")(bufname)
    if not root_dir then
      vim.notify("No ESLint flatfile config found, disabling for this buffer.", vim.log.levels.WARN)
      vim.lsp.buf_detach_client(bufnr, client.id)
    end
    if string.match(bufname, ".nuxt") then
      vim.lsp.buf_detach_client(bufnr, client.id)
    end
  end,
  -- Done by eslint_d from conform
  -- on_attach = function(client, bufnr)
  --   vim.api.nvim_create_autocmd("BufWritePre", {
  --     buffer = bufnr,
  --     command = "EslintFixAll",
  --   })
  -- end,
}
