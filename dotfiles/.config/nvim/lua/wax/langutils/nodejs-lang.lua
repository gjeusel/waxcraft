local Path = require("plenary.path")

-- Strategy:
--   1. use NVM_BIN env variable
--   2. use NVM_DIR env variable
--   3. fallback to "node"

-- The usual value is: NVM_DIR=$HOME/.nvm
-- And once loaded, got env variable:
-- NVM_BIN=$HOME/.nvm/versions/node/v17.4.0/bin

local opts = {
  fallback_version = "v17.4.0",
  nvm = {
    bin = os.getenv("NVM_BIN"),
    dir = os.getenv("NVM_DIR"),
  },
}

local node_path

if opts.nvm.bin then
  -- Optimal scenario
  node_path = Path:new(opts.nvm.bin):joinpath("node"):absolute()
elseif opts.nvm.dir then
  -- Fallback when nvm not yet loaded
  node_path = Path
    :new(opts.nvm.dir)
    :joinpath("/versions/node/")
    :joinpath(opts.fallback_version)
    :joinpath("node")
    :absolute()
else
  -- Fallback when no nvm found
  node_path = "node"
end

local global = {}
setmetatable(global, {
  __index = function(_, key) -- auto fallback to joinpath
    local path = Path:new(node_path):parent():joinpath(key)
    if path:exists() then
      return path:absolute()
    else
      return nil
    end
  end,
})

local find_root_dir = find_root_dir_fn({
  ".git",
  "Dockerfile",
  "package.json",
  "tsconfig.json",
})

return {
  find_root_dir = find_root_dir,
  path = node_path,
  global = global,
}
