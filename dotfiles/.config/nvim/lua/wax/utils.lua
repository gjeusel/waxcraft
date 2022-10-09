-------- Debug utils --------

function _G.dump(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
  print(unpack(objects))
end

-------- Mocks --------

function _G.mock()
  local Mock = {}

  setmetatable(Mock, {
    __call = function(cls, ...)
      return cls.new(...)
    end,
  })
  local mock_mt = {
    __call = function(self, ...)
      local args = { n = select("#", ...), ... }
      self._calls[#self._calls + 1] = args
    end,
    __index = Mock,
  }
  function Mock.new()
    local self = setmetatable({
      _calls = {},
    }, mock_mt)
    return self
  end

  return Mock
end

-------- Module Operations --------

---Return truthy if module is available
---@param name string
---@return boolean
function _G.is_module_available(name)
  if package.loaded[name] then
    return true
  else
    for _, searcher in ipairs(package.searchers or package.loaders) do
      local loader = searcher(name)
      if type(loader) == "function" then
        package.preload[name] = loader
        return true
      end
    end
    return false
  end
end

---Try to require. If module is not available, returns a mock.
---@param name string
---@return unknown
function _G.safe_require(name)
  if is_module_available(name) then
    return require(name)
  else
    return mock()
  end
end

-------- Logs --------

_G.log = safe_require("plenary.log").new({
  plugin = "wax",
  level = waxopts.loglevel,
  use_console = false,
})

-------- WorkSpace --------

function _G.is_git(cwd)
  local cmd = { "git", "rev-parse", "--show-toplevel" }
  local git_root, ret = require("telescope.utils").get_os_command_output(cmd, cwd)
  return not (ret ~= 0 or #git_root <= 0)
end

function _G.find_root_dir_fn(patterns)
  local default_patterns = {
    ".git",
    "Dockerfile",
    "pyproject.toml",
    "setup.cfg",
    "package.json",
    "tsconfig.json",
  }
  patterns = patterns or default_patterns
  return require("lspconfig").util.root_pattern(patterns)
end

function _G.find_root_dir(path)
  return find_root_dir_fn()(path)
end
