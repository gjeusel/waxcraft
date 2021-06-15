local pyls_config = require'lspinstall/util'.extract_config('pyls')

local conda_prefix = os.getenv('CONDA_PREFIX')
local conda_python_exec = os.getenv('CONDA_PYTHON_EXE')

local python_path
if conda_prefix then
  python_path = conda_prefix .. '/bin/python'
else
  python_path = conda_python_exec
end

local to_install = {
  '\'python-lsp-server[rope]\'', 'pyls-flake8', 'mypy-ls', 'pyls-isort', 'python-lsp-black',
  'flake8==3.9.2', 'flake8-bugbear==21.4.3', 'flake8-builtins==1.5.3', 'mypy==0.902',
  'black==19.10b0', 'isort==5.7.0',
}

local install_script = python_path .. ' -m pip install'
for _, dep in ipairs(to_install) do
  install_script = install_script .. ' ' .. dep
end

pyls_config.default_config.cmd[1] = 'pylsp'

require'lspinstall/servers'.pyls = vim.tbl_extend('error', pyls_config,
                                                  {install_script = install_script})

local config = {
  settings = {
    plugins = {
      flake8 = {},
      ['mypy-ls'] = {enabled = true, strict = false, live_mode = false, dmypy = true},
    },
  },
}

return config
