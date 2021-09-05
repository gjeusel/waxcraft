local Path = require("plenary.path")

M = {}

-- Helpers to find global npm setup

-- The usual value is:
-- NVM_DIR=$HOME/.nvm
-- And once loaded, got env variable:
-- NVM_BIN=$HOME/.nvm/versions/node/v16.3.0/bin
--
-- local nvm_dir = os.getenv("NVM_DIR")
-- if not nvm_bin then -- early return if nvm not installed
--   return {}
-- end

local node_path
if os.getenv("NVM_BIN") then
  node_path = Path:new(os.getenv("NVM_BIN")):parent()
else
  -- Fallback when nvm not yet loaded
  local node_version = "v16.3.0"
  node_path = Path:new(os.getenv("NVM_DIR") .. "/versions/node/" .. node_version)
end

M.global = { node_modules = node_path:joinpath("lib/node_modules"), bin = {} }

setmetatable(M.global.bin, {
  -- npm = nvm_bin_path:joinpath("npm"),
  -- yarn = nvm_bin_path:joinpath("yarn"),
  -- prettier = nvm_bin_path:joinpath("prettier"),

  __index = function(_, key) -- auto fallback to joinpath
    local path = node_path:joinpath("bin"):joinpath(key)
    -- dump(key, path:absolute(), path:exists())
    if path:exists() then
      return path:absolute()
    else
      return nil
    end
  end,
})

-- Helpers to find project npm setup
M.project = {}
M.project.find_root_dir = find_root_dir_fn({
  ".git",
  "Dockerfile",
  "package.json",
  "tsconfig.json",
})

return M
