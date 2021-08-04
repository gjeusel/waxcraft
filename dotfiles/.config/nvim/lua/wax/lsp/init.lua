-- Diagnostic Sign
vim.fn.sign_define(
  "LspDiagnosticsSignError",
  { texthl = "LspDiagnosticsSignError", text = "✗", numhl = "LspDiagnosticsSignError" }
)
vim.fn.sign_define(
  "LspDiagnosticsSignWarning",
  { texthl = "LspDiagnosticsSignWarning", text = "", numhl = "LspDiagnosticsSignWarning" }
)
vim.fn.sign_define("LspDiagnosticsSignInformation", {
  texthl = "LspDiagnosticsSignInformation",
  text = "",
  numhl = "LspDiagnosticsSignInformation",
})
vim.fn.sign_define(
  "LspDiagnosticsSignHint",
  { texthl = "LspDiagnosticsSignHint", text = "", numhl = "LspDiagnosticsSignHint" }
)

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

-- vim.lsp.set_log_level("debug")
vim.lsp.set_log_level("info")

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

-- make sure to require modules with overwrite of lspinstall beforehand
require("wax.lsp.pylsp-ls") -- define new config "pylsp"
require("wax.lsp.pyright-ls") -- define alias "pyright"
require("wax.lsp.yaml-ls") -- rewrite install setup

local lspinstall = require("lspinstall")
lspinstall.setup()

local required_servers = {
  -- generic
  "efm",
  -- vim / bash / json / yaml
  "lua",
  "bash",
  "yaml",
  "json",
  -- frontend
  "typescript",
  "html",
  "svelte",
  "vue",
  "css",
  "tailwindcss",
  "graphql",
  -- backend
  "pylsp",
  "pyright",
  "cmake",
  "rust",
  "go",
  -- infra
  "terraform",
}

local function setup_servers()
  local default_settings = { on_attach = on_attach, capabilities = lsp_status.capabilities }
  local installed_servers = require("lspinstall").installed_servers()
  for _, server in pairs(required_servers) do
    -- If "wax.lsp.{server}-ls.lua" exists, then load its settings
    local server_setting_module_path = "wax.lsp." .. server .. "-ls"
    local has_setting_module = is_module_available(server_setting_module_path)

    local custom_settings = {}
    if has_setting_module then
      log.debug(string.format("Configuring LSP '%s' with custom settings", server))
      custom_settings = require(server_setting_module_path) or {}
    else
      log.debug(string.format("Configuring LSP '%s'", server))
    end

    -- Chain potential on_attach
    if custom_settings.on_attach then
      local custom_on_attach = vim.deepcopy(custom_settings.on_attach)
      custom_settings.on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        custom_on_attach(client, bufnr)
      end
    end

    -- Install if not yet installed
    if not vim.tbl_contains(installed_servers, server) then
      log.info(string.format("Installing LSP '%s' ...", server))
      require("lspinstall").install_server(server)
    end

    -- Setup it
    local settings = vim.tbl_extend("keep", custom_settings, default_settings)
    require("lspconfig")[server].setup(settings)
  end
end

setup_servers()

-- Automatically reload after `:LspInstall <server>` so we don't have to restart neovim
require("lspinstall").post_install_hook = function()
  setup_servers() -- reload installed servers
  vim.cmd("bufdo e") -- this triggers the FileType autocmd that starts the server
end
