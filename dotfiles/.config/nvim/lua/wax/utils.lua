local telescope_utils = require("telescope.utils")

local M = {}


M.is_git = function(cwd)
  local cmd = { "git", "rev-parse", "--show-toplevel" }
  local git_root, ret = telescope_utils.get_os_command_output(cmd, cwd)
  if #git_root <= 0 then
    return false
  else
    return true
  end
end

M.get_os_command_output = telescope_utils.get_os_command_output


return M
