-- Set log level for LSP
vim.lsp.set_log_level(waxopts.loglevel)

-- Define custom ui settings
require("wax.lsp.ui")

-- https://github.com/nvim-lua/lsp-status.nvim#all-together-now
local lsp_status = require("lsp-status")
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
local function set_lsp_keymaps()
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)

  local function goto_first_definition()
    vim.lsp.buf.definition({
      on_list = function(options)
        vim.fn.setqflist({}, " ", options)
        vim.api.nvim_command("cfirst")
      end,
    })
  end
  vim.keymap.set("n", "gd", goto_first_definition, opts)
  vim.keymap.set("n", "<leader>d", goto_first_definition, opts)

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
end

set_lsp_keymaps()

--Enable completion triggered by <c-x><c-o>
vim.api.nvim_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

-- Generate capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_extend("force", capabilities, lsp_status.capabilities)
capabilities.textDocument.completion =
  require("cmp_nvim_lsp").default_capabilities({}).textDocument.completion

-- Customization of the publishDiagnostics (remove all pyright diags)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(function(_, result, ctx, config)
  result.diagnostics = vim.tbl_filter(function(diagnostic)
    -- Filter out all diagnostics from pyright
    return not vim.tbl_contains({ "Pyright" }, diagnostic.source)
  end, result.diagnostics)

  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
end, {})

-- Disable semanticTokens on lsp attach
--
-- should be done in on_attach setting it to nil, but buggy right now:
-- https://github.com/neovim/neovim/issues/21588
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    -- disable semanticTokens for now
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf
    vim.lsp.semantic_tokens.stop(bufnr, client.id)
    client.server_capabilities.semanticTokensProvider = nil
  end,
})

local default_on_attach = lsp_status.on_attach

local function lspconfig_setup()
  local scan = require("plenary.scandir")

  local server_with_custom_config = vim.tbl_map(function(server_file)
    return vim.fn.fnamemodify(server_file, ":t:r")
  end, scan.scan_dir(lua_waxdir .. "/lsp/servers", { depth = 1 }))

  for _, server_name in ipairs(server_with_custom_config) do
    local server_opts = require(("wax.lsp.servers.%s"):format(server_name))

    -- Maybe combine both on_attach
    local on_attach = default_on_attach
    if server_opts.on_attach then
      on_attach = function(client, bufnr)
        default_on_attach(client)
        server_opts.on_attach(client, bufnr)
      end
    end

    -- log.warn("Setting up", server_name, "with", server_opts)
    require("lspconfig")[server_name].setup(
      vim.tbl_deep_extend(
        "keep",
        { capabilities = capabilities, on_attach = on_attach },
        server_opts
      )
    )
  end
end

-- call lspconfig setup with our custom servers configs
lspconfig_setup()

-- -- Don't call the setup_handlers as it messes everything
-- require("mason-lspconfig").setup_handlers({
--   function(server_name)
--     require("lspconfig")[server_name].setup({
--       capabilities = capabilities,
--       on_attach = default_on_attach,
--     })
--   end,
-- })
