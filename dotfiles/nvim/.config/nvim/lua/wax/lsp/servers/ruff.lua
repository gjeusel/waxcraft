local python_utils = require("wax.lsp.python-utils")

return {
  filetypes = { "python" },
  settings = {
    -- https://github.com/charliermarsh/ruff-lsp#settings
    interpreter = { python_utils.get_python_path() },
    organizeImports = false,
  },
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace, "python")
    local new_workspace_name = to_workspace_name(new_workspace)

    if python_path == "python" then
      local msg = "LSP python (ruff-lsp) - keeping previous python path '%s' for new_root_dir '%s'"
      log.debug(msg:format(config.cmd[1], new_workspace))
      return config
    else
      local msg = "LSP python (ruff-lsp) - '%s' using path %s"
      log.debug(msg:format(new_workspace_name, python_path))

      config.settings.interpreter = { python_path }
      return config
    end
  end,
}
