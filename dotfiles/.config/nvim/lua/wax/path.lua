---@class Wax.Path
---@field path string
---@field type 'directory' | 'file'
local Path = {}

function Path:new(path)
  if type(path) == "table" and path.path ~= nil then
    path = path.path
  end
  if type(path) ~= "string" then
    error(("Tried to instantiate a Path using a '%s' type"):format(type(path)), 2)
  end
  local obj = { path = path }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

---Return the home path
---@return Wax.Path
function Path.home()
  return Path:new(os.getenv("HOME"))
end

---Return the lua wax directory ($HOME/.config/nvim/lua/wax)
---@return Wax.Path
function Path.waxdir()
  return Path:new(vim.fn.fnamemodify(debug.getinfo(1, "S").short_src, ":p:h"))
end

---Return the parent path
---@return Wax.Path
function Path:parent()
  local parent_path = vim.fn.fnamemodify(self.path, ":h")
  return Path:new(parent_path)
end

---Join paths
---@param ... string[]
---@return Wax.Path
function Path:join(...)
  local paths = { self.path, ... }
  local joined_path = table.concat(paths, "/")
  return Path:new(joined_path)
end

---Return the absolute path as a string
---@return string
function Path:absolute()
  local abs_path = vim.fn.fnamemodify(self.path, ":p")
  return abs_path
end

---Return the path as relative to
---@param base string | Wax.Path
---@return Wax.Path
function Path:make_relative(base)
  local self_path = self:absolute()
  local base_path = Path:new(base):absolute()
  if not vim.startswith(self_path, base_path) then
    return self
  end
  local relative_path = string.sub(self_path, #base_path + 1)
  return Path:new(relative_path)
end

---Return a table of files and directories in the current directory path
---@return Wax.Path[]
function Path:ls()
  local paths = {}
  local handle = vim.loop.fs_scandir(self.path)
  if not handle then
    return paths
  end
  while true do
    local name, _type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    local path = self:join(name)
    if _type == "directory" then
      path.type = "directory"
    else
      path.type = "file"
    end
    table.insert(paths, path)
  end
  return paths
end

---Check if the path is an existing file
---@return boolean
function Path:is_file()
  local is_file = vim.fn.filereadable(self.path) == 1
  return is_file
end

---Check if the path is a directory
---@return boolean
function Path:is_directory()
  local is_directory = vim.fn.isdirectory(self.path) == 1
  return is_directory
end

---Check if the path exists
---@return boolean
function Path:exists()
  return vim.fn.isdirectory(self.path) == 1 or vim.fn.filereadable(self.path) == 1
end

---Return table of paths matching the pattern
---@param pattern string
---@return Wax.Path[]
function Path:glob(pattern)
  local glob_path = self.path .. "/" .. pattern

  -- https://github.com/nvim-telescope/telescope.nvim/pull/2345/files
  local glob_path_sain = vim.fn.escape(glob_path, "?*[]")

  local files = vim.fn.glob(glob_path_sain, true, true)
  return vim.tbl_map(function(file)
    return Path:new(file)
  end, files)
end

---Return a function to find the root directory based on a list of patterns
---@param patterns table<string>
---@return Wax.Path | nil
function Path:find_root_dir(patterns)
  local current_path = self
  while current_path.path ~= "/" do
    for _, pattern in ipairs(patterns) do
      -- log.warn(("Checking for pattern '%s' at '%s'"):format(pattern, current_path.path))
      local paths = current_path:glob(pattern)
      if #paths > 0 then
        return current_path
      end
    end

    -- early stop to avoid infinite loop
    if current_path:parent().path == current_path.path then
      return nil
    end

    current_path = current_path:parent()
  end
  return nil
end

return Path
