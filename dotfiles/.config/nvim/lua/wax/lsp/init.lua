-- Set log level for LSP
vim.lsp.set_log_level(waxopts.lsp.loglevel)

-- Define custom ui settings
require("wax.lsp.ui")

-- https://github.com/nvim-lua/lsp-status.nvim#all-together-now
local lsp_status = safe_require("lsp-status")
lsp_status.register_progress()
lsp_status.config({
  current_function = false,
  show_filename = false,
  indicator_separator = " ",
  component_separator = " ",
  indicator_errors = "✗",
  indicator_info = "כֿ",
  indicator_warnings = "",
  indicator_hint = "",
  indicator_ok = "", -- "",
  status_symbol = "",
  update_interval = 100,
})

-- Mappings
local function lsp_keymaps()
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
  vim.keymap.set("n", "<leader>d", function()
    vim.lsp.buf.definition({
      on_list = function(options)
        vim.fn.setqflist({}, " ", options)
        vim.api.nvim_command("cfirst")
      end,
    })
  end, opts)

  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

  vim.keymap.set("n", "<leader>i", vim.lsp.buf.implementation, opts)
  vim.keymap.set("n", "<leader>I", vim.lsp.buf.declaration, opts)

  vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help)

  vim.keymap.set("n", "<leader>R", vim.lsp.buf.rename, opts)

  -- Mapping with selectors:
  vim.keymap.set("n", "<leader>fa", vim.lsp.buf.code_action, opts)

  local goto_win_opts = {
    float = {
      format = function(diag)
        return ("[%s] %s"):format(diag.source, diag.message)
      end,
      -- nvim_open_win generic:
      relative = "cursor",
      style = "minimal",
      border = "rounded",
      -- open_floating_preview generic:
      focusable = true,
      -- lsp win specific:
      scope = "cursor",
      header = "",
    },
  }
  vim.keymap.set("n", "å", function()
    vim.diagnostic.goto_prev(goto_win_opts)
  end, opts)
  vim.keymap.set("n", "ß", function()
    vim.diagnostic.goto_next(goto_win_opts)
  end, opts)

  vim.keymap.set({ "n", "v" }, "<leader>m", function()
    -- It defaults to range formatting when in visual mode
    --
    -- vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
    vim.lsp.buf.format({ async = true })
  end, opts)

  -- -- Custom ones:
  -- vim.keymap.set("n", "<leader>E", require('wax.lsp.lsp-functions').PeekTypeDefinition(), opts)
  -- vim.keymap.set("n", "<leader>e", require('wax.lsp.lsp-functions').PeekDefinition(), opts)
end

lsp_keymaps()

--Enable completion triggered by <c-x><c-o>
vim.api.nvim_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

-- Generate capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_extend("force", capabilities, lsp_status.capabilities)
if is_module_available("cmp_nvim_lsp") then
  capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
end

require("wax.lsp.setup").setup_servers({
  on_attach = lsp_status.on_attach,
  capabilities = capabilities,
})

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(function(_, result, ctx, config)
  result.diagnostics = vim.tbl_filter(function(diagnostic)
    -- Filter out all diagnostics from pyright
    return not vim.tbl_contains({ "Pyright" }, diagnostic.source)
  end, result.diagnostics)

  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
end, {})

-- setup null-ls
require("wax.lsp.null-ls")
