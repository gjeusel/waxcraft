local python_utils = require("wax.lsp.python-utils")

local debug_server = false

local function to_pylsp_cmd(workspace)
  workspace = workspace or find_workspace_name(vim.api.nvim_buf_get_name(0))
  local pylsp_path = python_utils.find_python_cmd(workspace, "pylsp")

  if debug_server then
    local log_dir = vim.env.HOME .. "/.cache/nvim"
    local log_file = log_dir .. "/pylsp.log"
    local cmd = { pylsp_path, "--check-parent-process", "--log-file", log_file }

    local map_loglevel = { trace = "-vvv", debug = "-vv", info = "-v" }
    local log_level = vim.tbl_get(map_loglevel, waxopts.loglevel)
    if log_level ~= nil then
      cmd = vim.list_extend(cmd, { log_level })
    end

    return cmd
  else
    return { pylsp_path }
  end
end

return {
  cmd = to_pylsp_cmd(),
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
        jedi_definition = {
          enabled = true,
          follow_imports = true,
          follow_builtin_imports = true,
          follow_builtin_definitions = true,
        },
        jedi_rename = { enabled = true },
        jedi_completion = {
          enabled = true,
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
        -- jedi_hover = { enabled = false },
        -- jedi_references = { enabled = false },
        -- jedi_rename = { enabled = false },
        -- jedi_highlight = { enabled = false },
        pylsp_mypy = {
          enabled = false,
          live_mode = false,
          dmypy = false,
          report_progress = false,
          -- args = {
          --   "--sqlite-cache", -- Use an SQLite database to store the cache.
          --   "--cache-fine-grained", -- Include fine-grained dependency information in the cache for the mypy daemon.
          -- },
        },
        -- Disabled ones:
        flake8 = { enabled = false },
        folding = { enabled = false },
        preload = { enabled = false },
        pycodestyle = { enabled = false },
        pydocstyle = { enabled = false },
        autopep8 = { enabled = false },
        mccabe = { enabled = false },
        pyflakes = { enabled = false },
        pylint = { enabled = false },
        rope = { enabled = false },
        rope_completion = { enabled = false },
        rope_autoimport = {
          enabled = false,
          -- memory = true,
          completions = { enabled = true },
          code_actions = { enabled = true },
        },
        rope_rename = { enabled = false },
        yapf = { enabled = false },
        -- Formatting is taken care of by null-ls
        ["pylsp_black"] = { enabled = false },
        ["pyls_isort"] = { enabled = false },
      },
    },
  },
  on_new_config = function(config, new_workspace)
    config.cmd = to_pylsp_cmd(new_workspace)
    return config
  end,
}
