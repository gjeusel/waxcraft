local python_utils = require("wax.lsp.python-utils")

return {
  filetypes = { "python" },
  settings = {
    -- https://github.com/charliermarsh/ruff-lsp#settings
    -- interpreter = {},
    organizeImports = false,
  },
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace, "python")

    local msg = "LSP python (ruff-lsp) - '%s' using path %s"
    log.info(msg:format(python_utils.workspace_to_project(new_workspace), python_path))

    config.settings.interpreter = { python_path }
    return config
  end,
}
