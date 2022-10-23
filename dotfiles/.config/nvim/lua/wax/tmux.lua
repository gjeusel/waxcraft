local M = {}

local function tmux_get_panes()
  local cmd = {
    "tmux",
    "list-panes",
    "-F",
    "#{session_name},#{window_index},#{pane_index},#{pane_bottom},#{pane_left},${pane_title},#{pane_current_command}",
  }
  local panes_raw = get_os_command_output(cmd)
  local panes = vim.tbl_map(function(e)
    local opts = vim.split(e, ",", {})
    return {
      session = opts[1],
      window = opts[2],
      pane = opts[3],
      bottom = opts[4],
      left = opts[5],
      title = opts[6],
      current_cmd = opts[7],
    }
  end, panes_raw)
  return panes
end

function M.tslime_select_target_pane()
  -- List of tmux 'named variables'  (#{...})
  -- https://gist.github.com/genki/22cace67e4fc7441222a06facee12b2e
  local cmd = {
    "tmux",
    "list-panes",
    "-F",
    "#{pane_index} - #{pane_title}",
  }

  vim.ui.select(get_os_command_output(cmd), {
    prompt = "Select tmux pane> ",
  }, function(_, i)
    vim.g.tslime = tmux_get_panes()[i]
  end)
end

function M.tslime_auto_select_bottom_pane()
  local panes = tmux_get_panes()
  table.sort(panes, function(left, right)
    if left["bottom"] == right["bottom"] then
      return left["left"] < right["left"]
    else
      return left["bottom"] > right["bottom"]
    end
  end)

  local pane = panes[1]

  if pane["current_cmd"] == "zsh" then
    log.debug("Tslime - auto set pane to", pane)
    vim.g.tslime = pane
  end
end

---------- Experiment: custom run in pane ----------
--

local TMUXKeys = {
  enter = "Enter",
}

local function tslime_to_target_pane()
  return vim.g.tslime.session .. ":" .. vim.g.tslime.window .. "." .. vim.g.tslime.pane
end

--- Run a bash command in tmux pane
---
--@param cmd table:
--        @key cmd[]: command list to execute

---Run os command in tmux pane
---@param cmd string[]
---@return nil
function M.run_in_pane(cmd)
  if not vim.g.tslime then
    M.tslime_auto_select_bottom_pane()
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
