-------- OS Operations --------
function get_os_command_output(cmd, cwd)
  local telescope_utils = require('telescope.utils')
  return telescope_utils.get_os_command_output(cmd, cwd)
end

function is_git(cwd)
  local cmd = {'git', 'rev-parse', '--show-toplevel'}
  local telescope_utils = require('telescope.utils')
  local git_root, ret = get_os_command_output(cmd, cwd)
  if ret ~= 0 or #git_root <= 0 then
    return false
  else
    return true
  end
end

function find_root_dir_fn()
  lspconfig = require('lspconfig')
  return lspconfig.util.root_pattern('.git', 'Dockerfile', 'pyproject.toml', 'setup.cfg',
                                     'package.json', 'tsconfig.json')
end

function find_root_dir(path)
  return find_root_dir_fn()(path)
end

function file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

-------- Module Operations --------

function is_module_available(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == 'function' then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

-------- Table Operations --------

local function clone_table(t, copies)
  if type(t) ~= 'table' then
    return t
  end

  copies = copies or {}
  if copies[t] then
    return copies[t]
  end

  local copy = {}
  copies[t] = copy

  for k, v in pairs(t) do
    copy[clone_table(k, copies)] = clone_table(v, copies)
  end

  setmetatable(copy, clone_table(getmetatable(t), copies))

  return copy
end

function merge_tables(...)
  local tables_to_merge = {...}
  assert(#tables_to_merge > 1, 'There should be at least two tables to merge them')

  for k, t in ipairs(tables_to_merge) do
    assert(type(t) == 'table', string.format('Expected a table as function parameter %d', k))
  end

  local result = clone_table(tables_to_merge[1])
  for i = 2, #tables_to_merge do
    local from = tables_to_merge[i]
    for k, v in pairs(from) do
      if type(v) == 'table' then
        result[k] = result[k] or {}
        assert(type(result[k]) == 'table', string.format('Expected a table: \'%s\'', k))
        result[k] = merge_tables(result[k], v)
      else
        result[k] = v
      end
    end
  end
  return result
end

-------- Debug utils --------
function dump(...)
  local objects = vim.tbl_map(vim.inspect, {...})
  print(unpack(objects))
end
