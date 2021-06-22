local yaml_config = require("lspinstall/util").extract_config("yamlls")

local new_install_config = vim.tbl_deep_extend("force", yaml_config, {
  default_config = {
    cmd = {"yaml-language-server", "--stdio"},
  },
  install_script = "npm install -g yaml-language-server", -- use npm globally
  uninstall_script = "npm uninstall -g yaml-language-server",
})

require("lspinstall/servers").yaml = new_install_config
return {}
