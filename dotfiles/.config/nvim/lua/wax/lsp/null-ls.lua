local builtins = require("null-ls.builtins")

local eslint_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "svelte",
}

local sources = {
  builtins.diagnostics.eslint_d.with({
    filetypes = eslint_filetypes,
  }),
}

require("null-ls").setup({
  debug = waxopts.loglevel == "debug",
  diagnostics_format = "(#{s}) #{c}: #{m}",
  root_dir = find_root_dir,
  update_in_insert = false,
  should_attach = function(bufnr)
    local fpath = vim.api.nvim_buf_get_name(bufnr)
    return not is_big_file(fpath)
  end,
  log = {
    enable = true,
    level = waxopts.loglevel,
    use_console = "async",
  },
  sources = sources,
})
