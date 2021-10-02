local root_pattern = require("lspconfig").util.root_pattern
local node = require("wax.lsp.nodejs-utils")
local Path = require("plenary.path")

local root_markers = {
  ".git/", -- front
  "package.json",
  "tsconfig.json", -- python
  "setup.cfg",
  "setup.py",
  "pyproject.toml",
  "requirement.txt",
}

local global_prettier = {
  formatCommand = node.global.bin.prettier .. " --stdin-filepath ${INPUT}",
  formatStdin = true,
}

local local_prettier = {
  formatCommand = "./node_modules/.bin/prettier --stdin-filepath ${INPUT}",
  formatStdin = true,
}

local isort = { formatCommand = "isort --profile=black --quiet -", formatStdin = true }
local black = { formatCommand = "black --quiet -", formatStdin = true }

-- NOTE: Has to be a list per language
local languages = {
  lua = {
    { -- Stylua: > cargo install stylua
      lintCommand = "",
      lintFormats = {},
      lintSource = "",
      formatCommand = "stylua --search-parent-directories --color Never --stdin-filepath ${INPUT} -",
      formatStdin = true,
    },
  },

  yaml = { global_prettier },

  -- Frontend
  vue = { local_prettier },
  typescript = { local_prettier },
  typescriptreact = { local_prettier },
  javascript = { local_prettier },
  javascriptreact = { local_prettier },
  css = { local_prettier },

  -- Backend
  python = { isort, black },

  -- brew install jq
  -- json = {{formatCommand = 'jq .'}},
}

local log_file = vim.env.HOME .. "/.cache/nvim/efm.log"

return {
  on_attach = function(client, _)
    -- efm is only for formatting
    client.resolved_capabilities.completion = false
    client.resolved_capabilities.hover = false
    client.resolved_capabilities.documentSymbol = false
    client.resolved_capabilities.codeAction = false
  end,
  cmd = {
    os.getenv("HOME") .. "/go/bin/efm-langserver",
    "-logfile",
    log_file,
    "-loglevel",
    "0",
    --   "-c",
    --   os.getenv("HOME") .. "/.config/efm-langserver/config.yaml",
  },
  filetypes = vim.tbl_keys(languages),
  init_options = {
    documentFormatting = true,
    hover = false,
    documentSymbol = false,
    codeAction = false,
    completion = false,
  },
  root_dir = function(fname)
    local root = root_pattern(root_markers)(fname)
    -- Default to current file directory in case of root not found
    -- (so formatters can still be applied in the case for example of a single python script)
    return root or Path:new(fname):parent():absolute()
  end,
  settings = {
    rootMarkers = root_markers,
    lintDebounce = 0, -- disable linting
    languages = languages,
  },
  on_new_config = function(config, new_workspace)
    local frontend_with_local_bin = {
      vue = { local_prettier },
      typescript = { local_prettier },
      typescriptreact = { local_prettier },
      javascript = { local_prettier },
      javascriptreact = { local_prettier },
      css = { local_prettier },
    }

    local frontend_with_global_bin = {
      vue = { global_prettier },
      typescript = { global_prettier },
      typescriptreact = { global_prettier },
      javascript = { global_prettier },
      javascriptreact = { global_prettier },
      css = { global_prettier },
    }

    if not Path:new("./node-modules/.bin/prettier"):exists() then
      log.debug("Found no local node bin at " .. new_workspace .. ", defaulting to global.")
      config.settings.languages = vim.tbl_deep_extend(
        "force",
        config.settings.languages,
        frontend_with_global_bin
      )
    else
      config.settings.languages = vim.tbl_deep_extend(
        "force",
        config.settings.languages,
        frontend_with_local_bin
      )
    end
    return config
  end,
}
