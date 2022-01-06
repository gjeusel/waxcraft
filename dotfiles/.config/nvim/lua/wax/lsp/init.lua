vim.lsp.set_log_level(waxopts.lsp.loglevel)

require("wax.lsp.ui")

-- https://github.com/nvim-lua/lsp-status.nvim#all-together-now
local lsp_status = require("lsp-status")
lsp_status.register_progress()
lsp_status.config({
  current_function = false,
  indicator_separator = " ",
  component_separator = " | ",
  indicator_errors = "✗",
  indicator_info = "",
  indicator_warnings = "",
  indicator_hint = "",
  indicator_ok = "",
  status_symbol = "",
})

-- mappings
local on_attach = function(client, bufnr)
  -- Lsp Status Line setup
  lsp_status.on_attach(client, bufnr)

  -- -- Lsp Signature setup
  -- require("lsp_signature").on_attach({
  --   bind = true,
  --   floating_window = false,
  --   hint_enable = true,
  --   hint_prefix = "🐼 ",
  --   extra_trigger_chars = {"(", ","},
  -- })

  -- vim.cmd([[autocmd CursorHoldI * silent! lua vim.lsp.buf.signature_help()]])

  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end
  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end

  --Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

  -- Mappings.
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap("n", "<leader>D", "<Cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
  buf_set_keymap("n", "<leader>d", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)

  buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)

  buf_set_keymap("n", "<leader>i", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  buf_set_keymap("n", "<leader>I", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)

  buf_set_keymap("i", "<C-x>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  buf_set_keymap("n", "<C-x>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)

  buf_set_keymap("n", "<leader>R", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)

  local goto_win_opts = {
    popup_opts = {
      relative = "cursor",
      focusable = false,
      style = "minimal",
      border = "rounded",
      show_header = false,
    },
  }
  _G._lsp_goto_prev = function()
    return vim.diagnostic.goto_prev(goto_win_opts)
  end
  _G._lsp_goto_next = function()
    return vim.diagnostic.goto_next(goto_win_opts)
  end
  buf_set_keymap("n", "å", "<cmd>lua _lsp_goto_prev()<CR>", opts)
  buf_set_keymap("n", "ß", "<cmd>lua _lsp_goto_next()<CR>", opts)
  -- buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)

  buf_set_keymap("n", "<leader>m", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  -- buf_set_keymap("n", "<leader>m", "<cmd>lua vim.lsp.buf.formatting_seq_sync()<CR>", opts)

  -- -- Custom ones:
  -- buf_set_keymap("n", "<leader>E", "<Cmd>lua require('wax.lsp.lsp-functions').PeekTypeDefinition()<CR>", opts)
  -- buf_set_keymap("n", "<leader>e", "<Cmd>lua require('wax.lsp.lsp-functions').PeekDefinition()<CR>", opts)
end

require("wax.lsp.setup").setup_servers({
  on_attach = on_attach,
  capabilities = lsp_status.capabilities,
})
