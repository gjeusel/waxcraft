local M = {}

local lspconfig = require("lspconfig")
local lspmason = require("mason-lspconfig")
local Package = require "mason-core.package"
-- lspmason.servers = require("mason-lspconfig.servers")

---@param global_on_attach function @The generic on_attach function.
---@return table @The lspconfig server configuration.
local function get_custom_settings_for_server(server_name, global_on_attach)
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
      global_on_attach(client, bufnr)
      custom_on_attach(client, bufnr)
    end
  end

  return custom_settings
end

---@param lspconfig_server_name string
local function resolve_package(lspconfig_server_name)
  local registry = require "mason-registry"
  local Optional = require "mason-core.optional"
  local server_mapping = require "mason-lspconfig.mappings.server"

  return Optional.of_nilable(server_mapping.lspconfig_to_package[lspconfig_server_name]):map(function(package_name)
    local ok, pkg = pcall(registry.get_package, package_name)
    if ok then
      return pkg
    end
  end)
end

---@param global_lsp_settings table @The global lspconfig server configuration.
function M.setup_servers(global_lsp_settings)
  global_lsp_settings = global_lsp_settings or {}

  for server_name, _ in pairs(waxopts.lsp._servers) do
    -- Re-construct full settings
    local custom_settings =
    get_custom_settings_for_server(server_name, global_lsp_settings.on_attach)
    local settings = vim.tbl_extend("keep", custom_settings, global_lsp_settings)

    -- Advertise capabilities to cmp_nvim_lsp
    if is_module_available("cmp_nvim_lsp") then
      settings.capabilities = require("cmp_nvim_lsp").default_capabilities(settings.capabilities)
    end

    -- Install if not yet installed
    local server_identifier, version = Package.Parse(server_name)
    resolve_package(server_identifier):if_present(
    ---@param pkg Package
      function(pkg)
        if not pkg:is_installed() then
          pkg:install {
            version = version,
          }
        end
      end
    )

    -- Finally, setup our settings in lspconfig
    lspconfig[server_name].setup(settings)
  end

  lspmason.setup()
end

return M
