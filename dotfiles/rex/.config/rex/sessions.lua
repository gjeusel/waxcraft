-- tmuxp-like session files. Each sessions/<name>.yml becomes an "Open Session: <name>" action in the
-- command palette, also run as `rex do session_<name>`. It creates the session, or switches to it
-- when one with that label exists. Adding a file needs `rex config reload`; edits to a file don't,
-- since it is read with yq (nix/pkgs.nix) at each run. sessions/renewex.yml documents the format.

local M = {}

local shell = "com.superlogical.terminal.shell"

-- The server runs with the bare macOS PATH, not the shell's: add the nix-darwin profile of yq.
local yq_path = "/run/current-system/sw/bin:" .. os.getenv("PATH")

local function as_list(value)
  if value == nil then
    return {}
  end

  return type(value) == "table" and value or { value }
end

local function expand_home(path)
  return path and (path:gsub("^~", os.getenv("HOME")))
end

-- A layout is a pane, or `{ split = "right" | "down", ratio = 0.5, panes = { first, second } }`.
-- Panes are appended to `panes` in the order Rex returns their block IDs.
local function build_layout(node, window, panes)
  node = node or {}

  if node.split == nil then
    local input = {}
    for _, command in ipairs(as_list(window.shell_command_before)) do
      table.insert(input, command)
    end
    for _, command in ipairs(as_list(node.shell_command)) do
      table.insert(input, command)
    end

    table.insert(panes, node)

    return rex.layout.block({
      flavor = shell,
      options = {
        cwd = expand_home(node.start_directory or window.start_directory),
        initial_input = #input > 0 and table.concat(input, "\n") .. "\n" or nil,
      },
    })
  end

  local split = ({ right = rex.layout.horizontal, down = rex.layout.vertical })[node.split]
  local children = node.panes or {}
  if split == nil or #children ~= 2 then
    error(("%s: a split needs `split: right|down` and two panes"):format(window.window_name), 0)
  end

  local first = build_layout(children[1], window, panes)
  local second = build_layout(children[2], window, panes)

  return split(node.ratio or 0.5, first, second)
end

local function find_session(label)
  local list, err = rex.call("session.list")
  if list == nil then
    error(err, 0)
  end

  for _, session in ipairs(list.sessions) do
    if session.label == label then
      return session.session_id
    end
  end

  return nil
end

local function create_session(spec)
  local windows, panes_by_window = {}, {}
  for _, window in ipairs(spec.windows or {}) do
    local panes = {}
    table.insert(windows, {
      window_label = window.window_name,
      layout = build_layout(window.layout, window, panes),
    })
    table.insert(panes_by_window, panes)
  end

  local created, err = rex.call("session.create", {
    label = spec.session_name,
    initial_windows = windows,
  })
  if created == nil then
    error(err, 0)
  end

  -- Rex activates the last window created. Focus each window's `focus` pane (or its first), the
  -- `focus` window (or the first) last, since focusing a block activates its window. This needs
  -- the caller attached to the new session, through `rex.call`: actions have no attach helper.
  local _, attach_err = rex.call("session.attach", { session_id = created.session_id })
  if attach_err ~= nil then
    error(attach_err, 0)
  end

  local focused_window = 1
  local order = {}
  for index, window in ipairs(spec.windows or {}) do
    if window.focus then
      focused_window = index
    end

    table.insert(order, index)
  end

  if #order > 0 then
    table.insert(order, table.remove(order, focused_window))
  end

  for _, index in ipairs(order) do
    local focused_pane = 1
    for pane_index, pane in ipairs(panes_by_window[index]) do
      if pane.focus then
        focused_pane = pane_index
      end
    end

    local _, focus_err = rex.session.focus_block({
      session_id = created.session_id,
      block_id = created.initial_windows[index].block_ids[focused_pane],
    })
    if focus_err ~= nil then
      error(focus_err, 0)
    end
  end

  rex.call("session.detach", { session_id = created.session_id })

  return created.session_id
end

local function open_session(path, ctx)
  local result, err = rex.exec({ "yq", ".", path }, { env = { PATH = yq_path } })
  if result == nil then
    error(err, 0)
  end
  if not result.ok then
    error(result.stderr, 0)
  end

  local spec = rex.json.decode(result.stdout)
  local session_id = find_session(spec.session_name) or create_session(spec)

  -- Only the app can switch to the session, so only when it ran the action. From the CLI, the
  -- app would need Remote Control in its Settings, and refusing would fail the whole action.
  if ctx.origin == "palette" or ctx.origin == "key" then
    rex.client.queue("session.select", { session_id = session_id })
  end

  return { session_id = session_id }
end

---Define an "Open Session" action for each YAML file in `dir`.
---@param dir string
function M.define(dir)
  local listing = rex.exec({ "ls", dir })
  if listing == nil or not listing.ok then
    return
  end

  for file in listing.stdout:gmatch("[^\n]+") do
    local name = file:match("^(.+)%.ya?ml$")
    if name then
      rex.action({
        name = "session_" .. name:lower():gsub("[^%w]", "_"),
        title = "Open Session: " .. name,
        category = "Session",
        keywords = "tmuxp session layout load",
        run = function(ctx)
          return open_session(dir .. "/" .. file, ctx)
        end,
      })
    end
  end
end

return M
