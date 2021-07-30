local python_utils = require("wax.lsp.python-utils")
local pyls_config = require("lspinstall/util").extract_config("pylsp")

local flake8_ignore = {
  "W503", -- W503: line break before binary operator
  "W504", -- W504: line break after binary operator

  "A001", -- A001 "id" is a python builtin and is being shadowed, consider renaming the variable
  "A002", -- A002 "type" is used as an argument and thus shadows a python builtin, consider renaming the argument
  "A003", -- A003 "id" is a python builtin, consider renaming the class attribute

  "B008", -- B008 Do not perform function calls in argument defaults

  "C901", -- C901: is too complex

  "E203", -- E203: whitespace before ':'
  "E266", -- E266: too many leading ' --' for block comment
  "E402", -- E402: Module level import not at top of file
  "E731", -- E731: Do not assign a lambda expression, use a def

  "W293", -- W293: blank line contains whitespace
}

local to_install = {
  "'python-lsp-server[rope]'", -- lsp
  "pyls-flake8", -- plugin for flake8
  -- 'flake8==3.9.2', 'flake8-bugbear==21.4.3', 'flake8-builtins==1.5.3',
  "pylsp-mypy-rnx", -- plugin for mypy | do not use 'mypy-ls' the official
  -- 'mypy==0.902',
  "python-lsp-black", -- plugin for black
  -- 'black==21.6b0',
  "pyls-isort", -- plugin for isort
  -- 'isort==5.7.0',
}

local log_file = vim.env.HOME .. "/.cache/nvim/pylsp.log"
local log_level = "-v" -- number of v is the level

local function set_lspinstall_pylsp(python_path)
  local install_script = python_path .. " -m pip install -U"
  local uninstall_script = python_path .. " -m pip uninstall --yes"
  for _, dep in ipairs(to_install) do
    install_script = install_script .. " " .. dep
    uninstall_script = uninstall_script .. " " .. dep
  end

  -- default python_path is the one deduced from CWD at vim startup
  local cmd = { python_path, "-m", "pylsp", "--log-file", log_file, log_level }

  -- Make sure to use 'lspinstall/servers' in requires as its changes the behavior.
  -- If "lspinstall.servers" was used, the variable 'servers' in the module won't be updated.
  -- TODO: investigate why the fuck ?
  require("lspinstall/servers")["pylsp"] = vim.tbl_deep_extend("force", pyls_config, {
    default_config = { cmd = cmd },
    filetypes = { "python", "pyrex" },
    install_script = install_script,
    uninstall_script = uninstall_script,
  })
end

-- init lspinstall with CWD at first
set_lspinstall_pylsp(python_utils.get_python_path(find_root_dir(".")))

return {
  -- if python format by efm, disable formatting capabilities for pylsp
  on_attach = function(client, _)
    client.resolved_capabilities.document_formatting = false
  end,
  settings = {
    pylsp = {
      -- https://github.com/python-lsp/python-lsp-server/blob/develop/CONFIGURATION.md
      plugins = {
        -- Formatting is taken care of by efm
        ["pylsp_black"] = { enabled = false },
        ["pyls_isort"] = { enabled = false },
        -- ["pylsp_black"] = { enabled = true },
        -- ["pyls_isort"] = { enabled = true },
        flake8 = {
          enabled = true,
          exclude = ".git,__pycache__,build,dist,.eggs",
          ignore = flake8_ignore,
        },
        jedi_completion = {
          eager = true,
          cache_labels_for = { "pandas", "numpy", "pydantic", "fastapi", "flask", "sqlalchemy" },
        },
        pylsp_mypy_rnx = {
          enabled = false,
          live_mode = false,
          dmypy = false,
          -- dmypy = true, -- prevent having live update (only on save), but is faster
          -- args = { "--sqlite-cache", "--ignore-missing-imports" },
          args = {
            "--sqlite-cache", -- Use an SQLite database to store the cache.
            "--cache-fine-grained", -- Include fine-grained dependency information in the cache for the mypy daemon.
          },
        },
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
    local python_path = M.on_new_workspace_python_path(new_workspace)

    if python_path == "python" then
      log.info(
        string.format(
          "LSP python - keeping previous python path '%s' for new_root_dir '%s'",
          config.cmd[1],
          new_workspace
        )
      )
      return config
    end

    log.info(
      string.format(
        "LSP python (pylsp) - new path '%s' for new_root_dir '%s'",
        python_path,
        new_workspace
      )
    )
    set_lspinstall_pylsp(python_path)
    config.cmd = { python_path, "-m", "pylsp", "--log-file", log_file, log_level }
    return config
  end,
}
