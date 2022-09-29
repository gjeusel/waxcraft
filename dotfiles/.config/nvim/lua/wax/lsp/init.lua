vim.lsp.set_log_level(waxopts.lsp.loglevel)

-- Define custom ui settings
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

-- Mappings
local function lsp_keymaps()
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
  vim.keymap.set("n", "<leader>d", vim.lsp.buf.definition, opts)

  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

  vim.keymap.set("n", "<leader>i", vim.lsp.buf.implementation, opts)
  vim.keymap.set("n", "<leader>I", vim.lsp.buf.declaration, opts)

  vim.keymap.set({ "i", "n" }, "<C-x>", vim.lsp.buf.signature_help, opts)

  vim.keymap.set("n", "<leader>R", vim.lsp.buf.rename, opts)

  -- Mapping with selectors:
  vim.keymap.set("n", "<leader>fa", vim.lsp.buf.code_action, opts)

  local goto_win_opts = {
    float = {
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

  local filteredFormatters = { "tsserver", "volar" }
  vim.keymap.set("n", "<leader>m", function()
    local filter = function(client)
      return not vim.tbl_contains(filteredFormatters, client.name)
    end
    -- vim.lsp.buf.format({ filter = filter, async = true })
    vim.lsp.buf.format({ filter = filter, async = false, timeout_ms = 2000 })
  end, opts)
  -- vim.keymap.set("n", "<leader>m", vim.lsp.buf.formatting_seq_sync, opts)

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
  capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)
end

require("wax.lsp.setup").setup_servers({
  on_attach = lsp_status.on_attach,
  capabilities = capabilities,
})

-- setup null-ls
require("wax.lsp.null-ls")
