local pyls_config = require'lspinstall/util'.extract_config('pylsp')

local root_dir = find_root_dir('.')

local python_path

if root_dir and file_exists(root_dir .. '/poetry.lock') then -- case with poetry
  ret = get_os_command_output({"poetry", "run", "which", "python"})
  python_path = ret[#ret]
else -- case with conda
  local conda_prefix = os.getenv('CONDA_PREFIX')
  local conda_python_exec = os.getenv('CONDA_PYTHON_EXE')
  if conda_prefix then
    python_path = conda_prefix .. '/bin/python'
  else
    python_path = conda_python_exec
  end
end

local python_path = "/Users/gjeusel/Library/Caches/pypoetry/virtualenvs/pocdagster-0VbcOlfK-py3.9/bin/python"

local to_install = {
  '\'python-lsp-server[rope]\'', -- lsp
  'pyls-flake8', -- plugin for flake8
  -- 'flake8==3.9.2', 'flake8-bugbear==21.4.3', 'flake8-builtins==1.5.3',
  'pylsp-mypy-rnx', -- plugin for mypy | do not use 'mypy-ls' the official
  -- 'mypy==0.902',
  'python-lsp-black', -- plugin for black
  -- 'black==21.6b0',
  'pyls-isort' -- plugin for isort
  -- 'isort==5.7.0',
}

local install_script = python_path .. ' -m pip install'
local uninstall_script = python_path .. ' -m pip uninstall --yes'
for _, dep in ipairs(to_install) do
  install_script = install_script .. ' ' .. dep
  uninstall_script = uninstall_script .. ' ' .. dep
end

local log_file = os.getenv('HOME') .. '/.cache/nvim/pylsp.log'
pyls_config.default_config.cmd = {python_path, '-m', 'pylsp', '--log-file', log_file, '-v'}


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
