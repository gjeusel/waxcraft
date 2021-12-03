-- Diagnostic Sign
local signs = { Error = "✗ ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

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

vim.lsp.set_log_level(waxopts.lsp.loglevel)

local float_win_opts = {
  relative = "cursor",
  focusable = false,
  style = "minimal",
  border = "rounded",
}

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
  buf_set_keymap("n", "<leader>D", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  buf_set_keymap("n", "<leader>d", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
  buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap("n", "<leader>i", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)

  buf_set_keymap("i", "<C-x>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  buf_set_keymap("n", "<C-x>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)

  -- buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap("n", "<leader>R", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  -- buf_set_keymap('n', '<leader>.', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)

  local goto_win_opts = {
    popup_opts = vim.tbl_extend("keep", { show_header = false }, float_win_opts),
  }
  _G._lsp_goto_prev = function()
    return vim.lsp.diagnostic.goto_prev(goto_win_opts)
  end
  _G._lsp_goto_next = function()
    return vim.lsp.diagnostic.goto_next(goto_win_opts)
  end
  buf_set_keymap("n", "å", "<cmd>lua _lsp_goto_prev()<CR>", opts)
  buf_set_keymap("n", "ß", "<cmd>lua _lsp_goto_next()<CR>", opts)
  -- buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)

  buf_set_keymap("n", "<leader>m", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  -- buf_set_keymap("n", "<leader>m", "<cmd>lua vim.lsp.buf.formatting_seq_sync()<CR>", opts)
end

-- Customize windows for Hover and Signature
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, float_win_opts)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
  vim.lsp.handlers.signature_help,
  vim.tbl_extend("keep", float_win_opts, { max_height = 3 })
)

-- Diagnostic publish
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics,
  {
    -- virtual_text = {
    --   prefix = "‣",
    --   spacing = 4,
    -- },
    virtual_text = false,
    signs = true,
    underline = false,
    update_in_insert = true,
    severity_sort = true,
  }
)

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

local lsp_installer = require("nvim-lsp-installer")
local lsp_installer_servers = require("nvim-lsp-installer.servers")

local function get_custom_settings_for_server(server_name)
  -- If "wax.lsp.{server}-ls.lua" exists, then load its settings
  local server_setting_module_path = "wax.lsp." .. server_name .. "-ls"
  local has_setting_module = is_module_available(server_setting_module_path)

  local custom_settings = {}
  if has_setting_module then
    log.debug(string.format("Configuring LSP '%s' with custom settings", server_name))
    custom_settings = require(server_setting_module_path) or {}
  else
    log.debug(string.format("Configuring LSP '%s'", server_name))
  end

  -- Chain potential on_attach
  if custom_settings.on_attach then
    local custom_on_attach = vim.deepcopy(custom_settings.on_attach)
    custom_settings.on_attach = function(client, bufnr)
      on_attach(client, bufnr)
      custom_on_attach(client, bufnr)
    end
  end

  return custom_settings
end

local function setup_servers()
  local base_settings = { on_attach = on_attach, capabilities = lsp_status.capabilities }

  local map_server_settings = {}
  for server_name, _ in pairs(waxopts.lsp._servers) do
    -- Re-construct full settings
    local custom_settings = get_custom_settings_for_server(server_name)
    local settings = vim.tbl_extend("keep", custom_settings, base_settings)

    -- Advertise capabilities to cmp_nvim_lsp
    if is_module_available("cmp_nvim_lsp") then
      settings.capabilities = require("cmp_nvim_lsp").update_capabilities(settings.capabilities)
    end

    -- Install if not yet installed
    local ok, server = lsp_installer_servers.get_server(server_name)
    if ok then
      if not server:is_installed() then
        server:install()
      end
      map_server_settings[server_name] = settings
    else
      -- Servers without any nvim-lsp-installer defined installer:
      require("lspconfig")[server_name].setup(settings)
    end
  end

  lsp_installer.on_server_ready(function(server)
    local opts = map_server_settings[server.name] or {}
    server:setup(opts)
    vim.cmd([[ do User LspAttachBuffers ]])
  end)
end

setup_servers()
