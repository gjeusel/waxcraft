local util = require('lspconfig/util')

local root_files = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile"
}

local root_dir = function(filename)
  return util.root_pattern(unpack(root_files))(filename) or
    util.path.dirname(filename)
end

local filetypes = { "python" }

-- npm i -g pyright
require('lspconfig').pyright.setup {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = filetypes,
  root_dir = root_dir,
  on_attach = require'lsp'.common_on_attach,
  handlers = {
    ["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
      virtual_text = {spacing = 0, prefix = ""},
      signs = true,
      underline = true,
      update_in_insert = true
    })
  },
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        diagnosticMode = "workspace",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      }
    }
  }
}
