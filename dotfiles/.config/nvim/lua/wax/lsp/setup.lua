local M = {}
local lsp_installer = require("nvim-lsp-installer")
lsp_installer.servers = require("nvim-lsp-installer.servers")

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

function M.setup_servers(opts)
  opts = opts or {}

  local map_server_settings = {}
  for server_name, _ in pairs(waxopts.lsp._servers) do
    -- Re-construct full settings
    local custom_settings = get_custom_settings_for_server(server_name)
    local settings = vim.tbl_extend("keep", custom_settings, opts)

    -- Advertise capabilities to cmp_nvim_lsp
    if is_module_available("cmp_nvim_lsp") then
      settings.capabilities = require("cmp_nvim_lsp").update_capabilities(settings.capabilities)
    end

    -- Install if not yet installed
    local ok, server = lsp_installer.servers.get_server(server_name)
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

return M
