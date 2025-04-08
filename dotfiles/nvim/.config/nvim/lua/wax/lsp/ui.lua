-- symbols for autocomplete
vim.lsp.protocol.CompletionItemKind = {
  "   (Text) ",
  "   (Method)",
  "   (Function)",
  "   (Constructor)",
  " ﴲ  (Field)",
  "[] (Variable)",
  "   (Class)",
  " ﰮ  (Interface)",
  "   (Module)",
  " 襁 (Property)",
  "   (Unit)",
  "   (Value)",
  " 練 (Enum)",
  "   (Keyword)",
  "   (Snippet)",
  "   (Color)",
  "   (File)",
  "   (Reference)",
  "   (Folder)",
  "   (EnumMember)",
  " ﲀ  (Constant)",
  " ﳤ  (Struct)",
  "   (Event)",
  "   (Operator)",
  "   (TypeParameter)",
}

-- Customize windows for Hover and Signature
local float_win_opts = {
  border = "rounded",
  relative = "cursor",
  style = "minimal",
}

vim.lsp.handlers["textDocument/hover"] =
  vim.lsp.with(vim.lsp.buf.hover, vim.tbl_extend("keep", float_win_opts, { focusable = true }))

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
  vim.lsp.buf.signature_help,
  vim.tbl_extend("keep", float_win_opts, { max_height = 3, focusable = false })
)

vim.diagnostic.config({
  -- virtual_text = {
  --   prefix = "‣",
  --   spacing = 4,
  -- },
  virtual_text = false,
  underline = false,
  update_in_insert = true,
  severity_sort = true,
  --
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "✗ ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      --
    },
    linehl = {},
    numhl = {
      [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
      [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
      [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
      [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
    },
  },
})

-- change border of LspInfo:
require("lspconfig.ui.windows").default_options.border = "rounded"
