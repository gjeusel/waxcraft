local Path = require("plenary.path")

M = {}

-- -- The usual value is:
-- -- NVM_DIR=$HOME/.nvm
-- -- And once loaded, got env variable:
-- -- NVM_BIN=$HOME/.nvm/versions/node/v16.3.0/bin
-- --
-- local nvm_dir = os.getenv("NVM_DIR")
-- if not nvm_bin then -- early return if nvm not installed
--   return {}
-- end

local nvm_bin_path = Path:new(os.getenv("NVM_DIR") .. "/versions/node/v16.3.0/bin")
M.path = {
  bin = nvm_bin_path,
  npm = nvm_bin_path:joinpath("npm"),
  yarn = nvm_bin_path:joinpath("yarn"),

  -- commands
  prettier = nvm_bin_path:joinpath("prettier"),
}

return M
