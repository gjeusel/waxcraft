local Path = require("plenary.path")

local M = {}

M.workspace_to_project = function(workspace)
  local workspace_abs = Path:new(workspace):absolute()
  local project = vim.fn.fnamemodify(workspace_abs, ":t:r")
  if project == "" then
    return nil
  else
    return project
  end
end

return M
