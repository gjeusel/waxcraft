local root_pattern = require('lspconfig').util.root_pattern

local efm_config = os.getenv('HOME') .. '/.config/efm-langserver/config.yaml'
local bin_path = os.getenv('HOME') .. '/go/bin/efm-langserver'

local root_markers = {
  '.git/', -- front
  'package.json', 'tsconfig.json', -- python
  'setup.cfg', 'setup.py', 'pyproject.toml', 'requirement.txt'
}

-- NOTE: Has to be a list per language
local languages = {
  -- brew install luarocks
  -- luarocks install --server=https://luarocks.org/dev luaformatter
  lua = {
    {
      formatCommand = 'lua-format -i --double-quote-to-single-quote --indent-width=2 --no-use-tab --column-limit=100',
      formatStdin = true
    }
  },

  -- brew install jq
  json = {{formatCommand = 'jq .'}},
}

return {
  cmd = {bin_path, '-c', efm_config},
  filetypes = vim.tbl_keys(languages),
  init_options = {
    documentFormatting = true,
    hover = true,
    documentSymbol = true,
    codeAction = true,
    completion = true
  },
  root_dir = function(fname)
    -- return root_pattern(".git")(fname) or
    --   root_pattern("package.json", "tsconfig.json", ".eslintrc.json")(fname) or
    --   root_pattern("setup.py", "setup.cfg", "pyproject.toml", "requirement.txt")(fname)
    return root_pattern(root_markers)(fname)
  end,
  settings = {rootMarkers = root_markers, lintDebounce = 200, languages = languages}
}
