local root_pattern = require("lspconfig").util.root_pattern

-- local efm_config = os.getenv('HOME') .. '/.config/efm-langserver/config.yaml'
local bin_path = os.getenv("HOME") .. "/go/bin/efm-langserver"

local root_markers = {
  ".git/", -- front
  "package.json",
  "tsconfig.json", -- python
  "setup.cfg",
  "setup.py",
  "pyproject.toml",
  "requirement.txt",
}

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

  -- brew install jq
  -- json = {{formatCommand = 'jq .'}},
}

local log_file = vim.env.HOME .. "/.cache/nvim/efm.log"

return {
  -- cmd = {bin_path, '-c', efm_config},
  cmd = { bin_path, "-logfile", log_file, "-loglevel", "0" },
  filetypes = vim.tbl_keys(languages),
  init_options = {
    documentFormatting = true,
    hover = true,
    documentSymbol = true,
    codeAction = true,
    completion = true,
  },
  root_dir = function(fname)
    return root_pattern(root_markers)(fname)
  end,
  settings = { rootMarkers = root_markers, lintDebounce = 400, languages = languages },
}
