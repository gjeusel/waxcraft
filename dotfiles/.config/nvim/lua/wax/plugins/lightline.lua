vim.api.nvim_exec(
  [[
" Statusline
function! LspStatus() abort
  if luaeval('#vim.lsp.buf_get_clients() > 0')
    return luaeval("require('lsp-status').status()")
  endif

  return ''
endfunction
]],
  false
)

-- dump(vim.api.nvim_exec("LspStatus()", true))

local ligthline_layout = {
  left = {
    { "mode", "paste" },
    { "readonly", "modified", "lspstatus" },
  },
  right = {
    {},
    {},
    { "gitbranch", "absolutepath", "filetype" },
  },
}

vim.g.lightline = {
  colorscheme = "gruvbox",
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
