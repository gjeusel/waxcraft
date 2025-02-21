---@class Wax.TmuxState
---@field target_pane Wax.TmuxPane | nil
---@field previous_panes Wax.TmuxPane[]
local M = {
  target_pane = nil,
  previous_panes = {},
}

---@class Wax.TmuxPane
---@field session string
---@field window string
---@field index string
---@field bottom string
---@field left string
---@field title string
---@field current_cmd string
---@field channel string

---Get list of tmux panes
---@return Wax.TmuxPane[]
function M.get_panes()
  -- List of tmux 'named variables'  (#{...})
  -- https://gist.github.com/genki/22cace67e4fc7441222a06facee12b2e
  local cmd = {
    "tmux",
    "list-panes",
    "-F",
    "#{session_name},#{window_index},#{pane_index},#{pane_bottom},#{pane_left},#{pane_title},#{pane_current_command}",
  }
  local panes_raw = get_os_command_output(cmd)
  local panes = vim.tbl_map(function(e)
    local opts = vim.split(e, ",", {})
    local pane = {
      session = opts[1],
      window = opts[2],
      index = opts[3],
      bottom = opts[4],
      left = opts[5],
      title = opts[6],
      current_cmd = opts[7],
    }
    pane.channel = pane.session .. ":" .. pane.window .. "." .. pane.index
    return pane
  end, panes_raw)

  M.previous_panes = panes
  return panes
end

---Heuristic to get bottom pane
---@param panes Wax.TmuxPane[]
---@return Wax.TmuxPane | nil
local function deduce_bottom_pane(panes)
  if #panes == 0 then
    -- not in tmux
    return nil
  end

  table.sort(panes, function(left, right)
    if left["bottom"] == right["bottom"] then
      return left["left"] < right["left"]
    else
      return left["bottom"] > right["bottom"]
    end
  end)

  local pane = panes[1]

  if pane.current_cmd == "zsh" then
    return pane
  else
    return nil
  end
end

--- @param callback fun(pane: Wax.TmuxPane)
function M.select_target_pane(callback)
  local panes = M.get_panes()
  local candidates = vim.tbl_filter(function(pane)
    return not vim.list_contains({ "nvim" }, pane.current_cmd)
  end, panes)

  if #candidates == 2 then
    local bottom_pane = deduce_bottom_pane(candidates)
    if bottom_pane then
      log.debug("[wax.tmux] auto set pane to #" .. bottom_pane.index)
      M.target_pane = bottom_pane

      if callback ~= nil then
        callback(bottom_pane)
      end
      return
    end
  end

  vim.ui.select(candidates, {
    prompt = "Select tmux pane> ",
    format_item = function(item)
      return table.concat({ item.current_cmd, item.title }, " | ")
    end,
  }, function(_, i)
    local selected = candidates[i]
    if selected == nil then
      return
    end

    M.target_pane = selected
    if callback ~= nil then
      callback(selected)
    end
  end)
end

---@param cmd string
---@param on_stdout? function
---@param warn boolean
function M._job(cmd, on_stdout, warn)
  log.debug(cmd)
  local job_id = vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    stdout_buffered = true,

    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 and warn then
        vim.notify(
          string.format("[wax.tmux] '%s...' failed", string.sub(cmd, 1, 23)),
          vim.log.levels.WARN
        )
      end
      log.debug("exit:", exit_code)
    end,

    on_stderr = function(_, data, _)
      if not warn then
        return
      end
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.notify("[wax.tmux] " .. line, vim.log.levels.WARN)
        end
      end
    end,

    on_stdout = on_stdout,
  })

  if job_id == 0 then
    vim.notify("[wax.tmux] invalid arguments on jobstart()", vim.log.levels.ERROR)
  elseif job_id == -1 then
    vim.notify("[wax.tmux] tmux is not available", vim.log.levels.ERROR)
  end
  return vim.fn.jobwait({ job_id })
end

---@class Wax.TmuxRunOpts
---@field pane string | nil
---@field interrupt_before boolean | nil
---@field clear_before boolean | nil

---Use send-keys to send command to tmux pane.
---@param target Wax.TmuxPane
---@param cmd string
---@param opts Wax.TmuxRunOpts
---@return boolean ok
function M.send(target, cmd, opts)
  -- Scrolling logs in other pane puts tmux in copy mode, which blocks
  -- command execution. Try exiting that first.
  M._job(string.format("tmux send -t %s -X cancel", target.channel), nil, false)

  cmd = string.gsub(cmd, '"', '\\"')
  cmd = string.gsub(cmd, "%$", "\\$")
  local c = string.format('tmux send -t %s " %s"', target.channel, cmd)

  if opts.interrupt_before then
    M._job(string.format("tmux send -t %s C-c", target.channel), nil, true)
  end
  if opts.clear_before then
    M._job(string.format("tmux send -t %s clear ENTER", target.channel), nil, true)
  end

  c = c .. " ENTER"

  return M._job(c, nil, true)[1] == -0
end

---Run os command in tmux pane
---@param cmd string[]
---@param opts Wax.TmuxRunOpts
---@return nil
function M.run_in_pane(cmd, opts)
  local default_opts = {
    pane = nil,
    --
    interrupt_before = false,
    clear_before = false,
  }
  opts = vim.tbl_extend("keep", opts, default_opts)

  if opts.pane then
    M.send(opts.pane, cmd, opts)
    return
  end

  if M.target_pane ~= nil and #M.previous_panes == #M.get_panes() then
    M.send(M.target_pane, cmd, opts)
    return
  end

  M.select_target_pane(function(selected_pane)
    M.send(selected_pane, cmd, opts)
  end)
end

return M
