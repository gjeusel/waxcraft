local yaml_config = require("lspinstall/util").extract_config("yamlls")
local node = require("wax.lsp.nodejs-utils")

if not node.global.bin.yarn then
  local cmd = node.global.bin.npm .. " install yarn -g"
  log.info("Installing yarn...")
  os.execute(cmd)
end

local yaml_language_server_path = node.global.bin["yaml-language-server"]
local yarn_path = node.global.bin.yarn

local new_install_config = vim.tbl_deep_extend("force", yaml_config, {
  default_config = { cmd = { yaml_language_server_path, "--stdio" } },
  install_script = yarn_path .. " global add yaml-language-server",
  uninstall_script = yarn_path .. " global remove yaml-language-server",
})

require("lspinstall/servers").yaml = new_install_config

return {
  settings = {
    yaml = {
      editor = { tabSize = 2, formatOnType = false },
      validate = true,
      hover = true,
      completion = true,
      format = {
        enable = true,
        proseWrap = "Never",
        printWidth = 120,
      },
    },
  },
}
