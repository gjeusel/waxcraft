local root_pattern = require("lspconfig").util.root_pattern
local nvm = require("wax.lsp.nvm-utils")
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
  formatCommand = nvm.path.prettier:absolute() .. " --stdin-filepath ${INPUT}",
  formatStdin = true,
}
local prettier = {
  formatCommand = "./node_modules/.bin/prettier --stdin-filepath ${INPUT}",
  formatStdin = true,
}

local isort = { formatCommand = "isort --profile=black --quiet -", formatStdin = true }
local black = { formatCommand = "black --quiet -", formatStdin = true }

-- NOTE: Has to be a list per language
local languages = {
  lua = {
    -- cargo install stylua
    {
      lintCommand = "",
      lintFormats = {},
      lintSource = "",
      formatCommand = "stylua --search-parent-directories --color Never --stdin-filepath ${INPUT} -",
      formatStdin = true,
    },
  },

  yaml = { global_prettier },

  -- Frontend
  vue = { prettier },
  typescript = { prettier },
  typescriptreact = { prettier },
  javascript = { prettier },
  javascriptreact = { prettier },
  css = { prettier },

  -- Backend
  python = { isort, black },

  -- brew install jq
  -- json = {{formatCommand = 'jq .'}},
}

local log_file = vim.env.HOME .. "/.cache/nvim/efm.log"

return {
  -- cmd = {
  --   os.getenv("HOME") .. "/go/bin/efm-langserver",
  --   "-c",
  --   os.getenv("HOME") .. "/.config/efm-langserver/config.yaml",
  -- },
  cmd = { os.getenv("HOME") .. "/go/bin/efm-langserver", "-logfile", log_file, "-loglevel", "0" },
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
}
