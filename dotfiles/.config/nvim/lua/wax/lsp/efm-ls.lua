local root_pattern = require('lspconfig').util.root_pattern

local efm_config = os.getenv('HOME') .. '/.config/efm-langserver/config.yaml'
local bin_path = os.getenv('HOME') .. '/go/bin/efm-langserver'

local root_markers = {
  '.git/', -- front
  'package.json', 'tsconfig.json', -- python
  'setup.cfg', 'setup.py', 'pyproject.toml', 'requirement.txt'
}

local flake8 = {
  lintCommand = 'flake8 --ignore=E501 --stdin-display-name ${INPUT} -',
  lintStdin = true,
  lintFormats = {'%f:%l:%c: %m'},
  lintSource = 'flake8'
}
local mypy = {
  lintCommand = 'mypy --show-column-numbers --sqlite-cache',
  lintFormats = {'%f:%l:%c: %trror: %m', '%f:%l:%c: %tarning: %m', '%f:%l:%c: %tote: %m'},
  lintIgnoreExitCode = true,
  lintSource = 'mypy'
}
local isort = {formatCommand = 'isort --profile black --quiet -', formatStdin = true}
local black = {formatCommand = 'black --quiet -', formatStdin = true}

-- NOTE: Has to be a list per language
local languages = {
  -- https://github.com/Koihik/LuaFormatter
  -- brew install luarocks
  -- luarocks install --server=https://luarocks.org/dev luaformatter
  lua = {
    {
      formatCommand = 'lua-format -i' ..
          ' --double-quote-to-single-quote --indent-width=2 --no-use-tab --column-limit=100' ..
          ' --no-keep-simple-function-one-line --no-keep-simple-control-block-one-line',
      formatStdin = true
    }
  },

  -- brew install jq
  -- json = {{formatCommand = 'jq .'}},

  -- pip install ...
  -- python = {flake8, isort, black},
  -- python = {flake8, mypy, isort, black},
  -- python = {isort, black},

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
    return root_pattern(root_markers)(fname)
  end,
  settings = {rootMarkers = root_markers, lintDebounce = 400, languages = languages}
}
