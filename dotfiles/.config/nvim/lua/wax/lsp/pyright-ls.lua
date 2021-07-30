require("lspinstall/servers")["pyright"] = require("lspinstall/servers")["python"] -- pyright is named 'python' in lspinstall

local python_utils = require("wax.lsp.python-utils")

return {
  settings = {
    python = {
      disableOrganizeImports = true,
      pythonPath = "python",
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        typeCheckingMode = "normal",
        diagnosticMode = "workspace",
      },
    },
  },
  on_new_config = function(config, new_workspace)
    local python_path = M.on_new_workspace_python_path(new_workspace)

    if python_path == "python" then
      log.info(
        string.format(
          "LSP python - keeping previous python path '%s' for new_root_dir '%s'",
          config.pythonPath,
          new_workspace
        )
      )
      return config
    end

    log.info(
      string.format(
        "LSP python (pyright) - new path '%s' for new_root_dir '%s'",
        python_path,
        new_workspace
      )
    )
    config.pythonPath = python_path
    return config
  end,
}
