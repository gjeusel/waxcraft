local pyls_config = require'lspinstall/util'.extract_config('pylsp')

local conda_prefix = os.getenv('CONDA_PREFIX')
local conda_python_exec = os.getenv('CONDA_PYTHON_EXE')

local python_path
if conda_prefix then
  python_path = conda_prefix .. '/bin/python'
else
  python_path = conda_python_exec
end

local to_install = {
  '\'python-lsp-server[rope]\'', -- lsp
  'pyls-flake8', 'flake8==3.9.2', 'flake8-bugbear==21.4.3', 'flake8-builtins==1.5.3', -- flake8
  -- do not use 'mypy-ls' as improved at 'pylsp-mypy-rnx'
  'mypy==0.902', 'pylsp-mypy-rnx', -- mypy
  -- 'python-lsp-black', 'black==19.10b0', -- black
  'python-lsp-black', 'black==21.6b0', -- black
  'pyls-isort', 'isort==5.7.0' -- isort
}

local install_script = python_path .. ' -m pip install'
local uninstall_script = python_path .. ' -m pip uninstall --yes'
for _, dep in ipairs(to_install) do
  install_script = install_script .. ' ' .. dep
  uninstall_script = uninstall_script .. ' ' .. dep
end

local log_file = os.getenv('HOME') .. '/.cache/nvim/pylsp.log'
pyls_config.default_config.cmd = {'pylsp', '--log-file', log_file, '-v'}

require'lspinstall/servers'.pylsp = vim.tbl_extend('error', pyls_config, {
  install_script = install_script,
  uninstall_script = uninstall_script
})

return {
  -- init_options = {documentFormatting = false},
  settings = {
    pylsp = {
      plugins = {
        flake8 = {enabled = true},
        ['pylsp_black'] = {enabled = true},
        ['pyls_isort'] = {enabled = true},
        pylsp_mypy_rnx = {
          enabled = true,
          -- live_mode = true,
          -- live_mode = false,
          dmypy = true, -- prevent to have live update (only on save)
          args = {'--sqlite-cache', '--ignore-missing-imports'}
        }
      }
    }
  }
}
