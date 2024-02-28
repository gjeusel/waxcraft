local u = require("null-ls.utils")
local builtins = require("null-ls.builtins")
local python_utils = require("wax.lsp.python-utils")

local eslint_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "svelte",
}

local from_python_env = wax_cache_fn(function(params)
  local workspace = u.get_root()
  local cmd = python_utils.get_python_path(workspace, params.command)
  return cmd
end)

local sources = {
  -- builtins.diagnostics.mypy.with({
  --   command = "mypy",
  --   dynamic_command = from_python_env,
  -- }),
  -- builtins.diagnostics.eslint_d.with({
  --   filetypes = eslint_filetypes,
  -- }),
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
