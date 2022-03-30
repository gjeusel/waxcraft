local M = {}

local TMUXKeys = {
  enter = "Enter",
}

local function check_tsline_pane_defined()
  if not vim.g.tslime then
    vim.notify("tslime not defined")
    return false
  end
  return true
end

local function tslime_to_target_pane()
  return vim.g.tslime.session .. ":" .. vim.g.tslime.window .. "." .. vim.g.tslime.pane
end

--- Run a bash command in tmux pane
---
--@param cmd table:
--        @key cmd[]: command list to execute
M.run_in_pane = function(cmd)
  if not check_tsline_pane_defined() then
    return nil
  end

  local target_pane = tslime_to_target_pane()
  local args = { "send-keys", "-t", target_pane, table.concat(cmd, " "), TMUXKeys.enter }

  local handle
  handle, _ = vim.loop.spawn("tmux", { args = args }, function(code)
    handle:close()
    if code ~= 0 then
      vim.notify(
        string.format("Terminal exited %d running %s %s", code, "tmux", table.concat(args, " ")),
        vim.log.levels.ERROR
      )
    end
  end)

  return handle
end

return M
