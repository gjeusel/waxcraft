vim.api.nvim_create_user_command("LspStatus", function ()
  if vim.lsp.buf_get_clients() > 0 then
    return safe_require("lsp-status").status()
  else
    return ""
  end
end, {
  desc = "Return current lsp status."
})

local ligthline_layout = {
  left = {
    { "mode" },
    { "spell", "readonly", "modified", "lspstatus" },
  },
  right = {
    {},
    {},
    { "gitbranch", "absolutepath", "column", "filetype" },
  },
}

vim.g.lightline = {
  colorscheme = waxopts.colorscheme,
  component_function = { gitbranch = "FugitiveHead", lspstatus = "LspStatus" },
  -- component_expand = {  -- custom components
  -- },
  component_type = { -- color to components
    linter_warnings = "warning",
    linter_errors = "error",
    linter_ok = "left",
  },
  active = ligthline_layout,
  inactive = ligthline_layout,
}
