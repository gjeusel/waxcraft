-- Diagnostic Sign
local signs = { Error = "✗ ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

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
  vim.lsp.with(vim.lsp.handlers.hover, vim.tbl_extend("keep", float_win_opts, { focusable = true }))

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
  vim.lsp.handlers.signature_help,
  vim.tbl_extend("keep", float_win_opts, { max_height = 3, focusable = false })
)

vim.diagnostic.config({
  -- virtual_text = {
  --   prefix = "‣",
  --   spacing = 4,
  -- },
  virtual_text = false,
  signs = true,
  underline = false,
  update_in_insert = true,
  severity_sort = true,
})
