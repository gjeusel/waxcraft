local python_utils = require("wax.lsp.python-utils")


local function to_pylsp_cmd(python_path)
  local log_dir = vim.env.HOME .. "/.cache/nvim"
  local log_file = log_dir .. "/pylsp.log"

  local map_loglevel = { trace = "-vvv", debug = "-vv", info = "-v", warn = "-v", error = "-v" }
  local log_level = map_loglevel[waxopts.lsp.loglevel]

  local cmd = { python_path, "-m", "pylsp", "--log-file", log_file, log_level }

  return cmd
end

-- init nvim-lsp-installer with CWD at first
local initial_workspace = find_root_dir(".")

return {
  -- if python format by efm, disable formatting capabilities for pylsp
  on_attach = function(client, _)
    -- formatting is done by null-ls
    client.server_capabilities.document_formatting = false
  end,
  settings = {
    pylsp = {
      -- https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
      plugins = {
        -- Formatting is taken care of by null-ls
        ["pylsp_black"] = { enabled = false },
        ["pyls_isort"] = { enabled = false },
        flake8 = { enabled = false },
        -- flake8 = {
        --   enabled = true,
        --   exclude = ".git,__pycache__,build,dist,.eggs",
        --   ignore = flake8_ignore,
        -- },
        jedi_completion = {
          eager = true,
          cache_labels_for = { "pandas", "numpy", "pydantic", "fastapi", "flask", "sqlalchemy" },
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
        pylsp_mypy_rnx = { enabled = false },
        -- pylsp_mypy_rnx = {
        --   log = { file = log_dir .. "/pylsp-mypy-rnx.log", level = "DEBUG" },
        --   enabled = true,
        --   live_mode = false,
        --   dmypy = true,
        --   daemon_args = {
        --     start = { "--log-file", log_dir .. "/dmypy.log" },
        --     check = { "--perf-stats-file", log_dir .. "/dmypy-check-perfs.json" },
        --   },
        --   args = {
        --     "--sqlite-cache", -- Use an SQLite database to store the cache.
        --     "--cache-fine-grained", -- Include fine-grained dependency information in the cache for the mypy daemon.
        --   },
        -- },
        -- Disabled ones:
        mccabe = { enabled = false },
        preload = { enabled = false },
        pycodestyle = { enabled = false },
        pyflakes = { enabled = false },
        pylint = { enabled = false },
        rope_completion = { enabled = false },
        yapf = { enabled = false },
      },
    },
  },
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.get_python_path(new_workspace, "python")

    local msg = "LSP python (pylsp) - '%s' using path %s"
    log.info(msg:format(python_utils.workspace_to_project(new_workspace), python_path))

    if python_path == "python" then
      msg = "LSP python (pylsp) - keeping previous python path '%s' for new_root_dir '%s'"
      log.info(msg:format(config.cmd[1], new_workspace))
      return config
    end

    msg = "LSP python (pylsp) - new path '%s' for new_root_dir '%s'"
    log.info(msg:format(python_path, new_workspace))

    -- Update nvim-lsp-installer pylsp server by re-creating it
    local project = python_utils.workspace_to_project(new_workspace)

    local msg = "LSP python (pylsp) - '%s' using path %s"
    log.info(msg:format(project, python_path))

    local cmd = to_pylsp_cmd(python_path)
    config.cmd = cmd
    return config
  end,
}
