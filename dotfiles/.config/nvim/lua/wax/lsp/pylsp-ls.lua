local lspconfig_util = require('lspconfig/util')
local path = lspconfig_util.path

local pyls_config = require'lspinstall/util'.extract_config('pylsp')

local function get_python_path(workspace)
  -- https://github.com/neovim/nvim-lspconfig/issues/500#issuecomment-851247107

  -- If is poetry project, find the associated venv and use it
  -- TODO: find a faster way to do so, as it takes:
  --       ~ 0.3 seconds for conda run -n base
  --       ~ 0.3 seconds for poetry run which python
  if file_exists(path.join(workspace, 'poetry.lock')) then
    -- Make sure to not mess up with potential activated conda env
    local poetry_cmd = {'poetry', 'run', 'which', 'python'}
    if vim.env.CONDA_PREFIX then
      local cmd = {'conda', 'run', '-n', 'base', unpack(poetry_cmd)}
      local stdout, ret = get_os_command_output(cmd, workspace)
      if ret == 0 and #stdout > 1 then
        return stdout[#stdout - 1]
      end
    else
      local stdout, ret = get_os_command_output(poetry_cmd, workspace)
      if ret == 0 and #stdout ~= 0 then
        return stdout[#stdout]
      end
    end
  end

  -- If conda env is activated, use it
  if vim.env.CONDA_PREFIX then
    return path.join(vim.env.CONDA_PREFIX, 'bin', 'python')
  end

  -- If virtualenv is activated, use it
  if vim.env.VIRTUAL_ENV then
    return path.join(vim.env.VIRTUAL_ENV, 'bin', 'python')
  end

  -- Fallback to system Python.
  return 'python'
end


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


local log_file = vim.env.HOME .. '/.cache/nvim/pylsp.log'

local function set_lspinstall_pylsp(python_path)
  local install_script = python_path .. ' -m pip install'
  local uninstall_script = python_path .. ' -m pip uninstall --yes'
  for _, dep in ipairs(to_install) do
    install_script = install_script .. ' ' .. dep
    uninstall_script = uninstall_script .. ' ' .. dep
  end

  -- default python_path is the one deduced from CWD at vim startup
  local cmd = {python_path, '-m', 'pylsp', '--log-file', log_file, '-v'}
  pyls_config.default_config.cmd = cmd

  require'lspinstall/servers'.pylsp = vim.tbl_extend('error', pyls_config, {
    install_script = install_script,
    uninstall_script = uninstall_script
  })
end


-- init lspinstall with CWD at first
set_lspinstall_pylsp(get_python_path(find_root_dir('.')))

return {
  -- init_options = {documentFormatting = false}, -- if python format by efm
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
  },
  on_new_config = function(new_config, new_root_dir)
    local python_path = get_python_path(new_root_dir)
    log.debug('LSP python path: ', python_path)
    set_lspinstall_pylsp(python_path)
    new_config.cmd = {python_path, '-m', 'pylsp', '--log-file', log_file, '-v'}
  end
}
