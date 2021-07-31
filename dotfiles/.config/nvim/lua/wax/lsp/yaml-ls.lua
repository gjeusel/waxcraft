local yaml_config = require("lspinstall/util").extract_config("yamlls")
local nvm = require("wax.lsp.nvm-utils")

-- if not yarn_path:exists() then
--   local cmd = npm_path.path .. " install yarn -g"
--   os.execute(cmd)
-- end

local new_install_config = vim.tbl_deep_extend("force", yaml_config, {
  default_config = { cmd = { nvm.path.bin:joinpath("yaml-language-server"):absolute(), "--stdio" } },
  install_script = nvm.path.yarn:absolute() .. " global add yaml-language-server",
  uninstall_script = nvm.path.yarn:absolute() .. " global remove yaml-language-server",
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
