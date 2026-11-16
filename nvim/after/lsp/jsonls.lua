-- Maybe add schemastore for classic json schemas
local json = {}
if is_module_available("schemastore") then
  json = {
    schemas = require("schemastore").json.schemas(),
    validate = { enable = true },
  }
end

-- The server hardcodes trailing commas in jsonc as a warning, with no setting to turn it off.
local TRAILING_COMMA = 519

local function without_trailing_commas(bufnr, diagnostics)
  if not bufnr or vim.bo[bufnr].filetype ~= "jsonc" then
    return diagnostics
  end

  return vim.tbl_filter(function(diagnostic)
    return diagnostic.code ~= TRAILING_COMMA
  end, diagnostics)
end

return {
  -- cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  init_options = { provideFormatter = false }, -- better done by jq
  handlers = {
    ["textDocument/publishDiagnostics"] = function(err, result, ctx)
      if result and result.diagnostics then
        result.diagnostics =
          without_trailing_commas(vim.uri_to_bufnr(result.uri), result.diagnostics)
      end

      vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
    end,
    ["textDocument/diagnostic"] = function(err, result, ctx)
      if result and result.items then
        result.items = without_trailing_commas(ctx.bufnr, result.items)
      end

      return vim.lsp.diagnostic.on_diagnostic(err, result, ctx)
    end,
  },
  settings = {
    json = json,
    -- configure = {
    --   allowComments = true,
    -- },
  },
}
