local python_utils = require("wax.lsp.python-utils")

return {
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace)
    local new_workspace_name = to_workspace_name(new_workspace)

    if python_path == "python" then
      local msg = "LSP python (mypygls) - keeping previous python path '%s' for new_root_dir '%s'"
      log.debug(msg:format(config.cmd[1], new_workspace))
      return config
    else
      local msg = "LSP python (mypygls) - '%s' using path %s"
      log.info(msg:format(new_workspace_name, python_path))

      config.cmd = { python_path, "-m", "mypygls" }
      return config
    end
  end,
}
