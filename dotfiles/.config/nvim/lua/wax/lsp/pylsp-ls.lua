local python_utils = require("wax.lsp.python-utils")

local function to_pylsp_cmd(python_path)
  local log_dir = vim.env.HOME .. "/.cache/nvim"
  local log_file = log_dir .. "/pylsp.log"

  local map_loglevel = { trace = "-vvv", debug = "-vv", info = "-v", warn = "-v", error = "-v" }
  local log_level = map_loglevel[waxopts.lsp.loglevel]

  local cmd = { python_path, "-m", "pylsp", "--log-file", log_file, log_level }

  return cmd
end

return {
  -- if python format by efm, disable formatting capabilities for pylsp
  on_attach = function(client, _)
    -- formatting is done by null-ls
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  settings = {
    pylsp = {
      -- https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
      plugins = {
        jedi_rename = { enabled = true },
        jedi_completion = {
          eager = true,
          cache_labels_for = {
            "pandas",
            "numpy",
            "pydantic",
            "fastapi",
            "flask",
            "sqlalchemy",
            "dagster",
          },
        },
        pylsp_mypy = {
          enabled = false,
          live_mode = false,
          -- dmypy = true,
          args = {
            "--sqlite-cache", -- Use an SQLite database to store the cache.
            "--cache-fine-grained", -- Include fine-grained dependency information in the cache for the mypy daemon.
          },
        },
        -- Disabled ones:
        flake8 = { enabled = false },
        mccabe = { enabled = false },
        preload = { enabled = false },
        pycodestyle = { enabled = false },
        pyflakes = { enabled = false },
        pylint = { enabled = false },
        rope = { enabled = true },
        rope_completion = { enabled = true },
        rope_rename = { enabled = false },
        yapf = { enabled = false },
        -- still unsure:
        -- jedi_completion = { enabled = false }, -- done better by pyright ?
        -- Formatting is taken care of by null-ls
        ["pylsp_black"] = { enabled = false },
        ["pyls_isort"] = { enabled = false },
      },
    },
  },
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace, "python")
    local new_workspace_name = to_workspace_name(new_workspace)

    if python_path == "python" then
      local msg = "LSP python (pylsp) - keeping previous python path '%s' for new_root_dir '%s'"
      log.debug(msg:format(config.cmd[1], new_workspace))
      return config
    else
      local msg = "LSP python (pylsp) - '%s' using path %s"
      log.info(msg:format(new_workspace_name, python_path))

      config.cmd = to_pylsp_cmd(python_path)
      return config
    end
  end,
}
