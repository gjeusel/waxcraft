-- Dispatch commands to another tiled terminal in Neovim's Rex window.
local M = {}

local target_block_id
local shells = { zsh = true, bash = true, sh = true, fish = true, nu = true }

-- Find the window containing this Neovim, not the active window: focus may have changed while
-- a test picker was open. Floating scrollback viewers must never become test targets.
local panes_script = [[
local view, err = rex.session.view({})
if view == nil then
  error(err, 0)
end

for _, window in ipairs(view.windows or {}) do
  local contains_self = false
  for _, layer in ipairs(window.layers) do
    for _, block in ipairs(layer.blocks or {}) do
      contains_self = contains_self or block.block_id == rex.block_id
    end
  end

  if contains_self then
    local panes = {}
    local function collect(node, blocks)
      if node == nil then
        return
      end
      if node.split then
        collect(node.split.before, blocks)
        collect(node.split.after, blocks)
        return
      end

      local block = blocks[node.block_id]
      if block == nil or block.block_id == rex.block_id
        or block.flavor ~= "com.superlogical.terminal.shell" then
        return
      end

      local process, process_err = rex.block.call("com.superlogical.terminal", "process", {
        block_id = block.block_id,
      })
      if process == nil then
        error(process_err, 0)
      end

      local foreground = process.foreground
      local name = foreground and foreground.name or ""
      name = name:gsub("^%.", ""):gsub("%-wrapped$", "")
      if name ~= "nvim" and name ~= "vim" then
        panes[#panes + 1] = {
          block_id = block.block_id,
          title = block.label,
          current_cmd = name,
          bottom = node.rect[2] + node.rect[4],
          left = node.rect[1],
        }
      end
    end

    for _, layer in ipairs(window.layers) do
      if layer.kind == "tiled" then
        local blocks = {}
        for _, block in ipairs(layer.blocks or {}) do
          blocks[block.block_id] = block
        end
        collect(layer.layout, blocks)
      end
    end
    return { panes = panes }
  end
end

error("Neovim's Rex pane is no longer in a window", 0)
]]

local function run(arguments, stdin)
  local rex = vim.env.REX_BIN_DIR and vim.fs.joinpath(vim.env.REX_BIN_DIR, "rex") or "rex"
  if vim.fn.executable(rex) == 0 then
    rex = "rex"
  end

  local command = { rex }
  vim.list_extend(command, arguments)
  local result = vim.system(command, { text = true, stdin = stdin }):wait()
  if result.code ~= 0 then
    vim.notify(
      "[wax.rex] " .. vim.trim(result.stderr or "Rex command failed"),
      vim.log.levels.ERROR
    )
    return nil
  end

  return result.stdout
end

function M.get_panes()
  local output = run({ "do", "-b", vim.env.REX_BLOCK, "--json", "-e", panes_script })
  if output == nil then
    return nil
  end

  return vim.json.decode(output).panes
end

local function select_pane(panes, callback)
  if #panes == 0 then
    vim.notify("[wax.rex] No other terminal pane in this window", vim.log.levels.WARN)
    return
  end

  local function selected(pane)
    if pane == nil then
      return
    end

    target_block_id = pane.block_id
    if callback then
      callback(pane)
    end
  end

  if #panes == 1 then
    selected(panes[1])
    return
  end

  -- Match wax.tmux: with two candidates, prefer a shell in the bottom-left pane.
  table.sort(panes, function(a, b)
    if a.bottom == b.bottom then
      return a.left < b.left
    end

    return a.bottom > b.bottom
  end)
  if #panes == 2 and shells[panes[1].current_cmd] then
    selected(panes[1])
    return
  end

  vim.ui.select(panes, {
    prompt = "Select Rex test pane> ",
    format_item = function(pane)
      return table.concat({ pane.current_cmd, pane.title, pane.block_id:sub(-6) }, " | ")
    end,
  }, selected)
end

function M.select_target_pane(callback)
  local panes = M.get_panes()
  if panes then
    select_pane(panes, callback)
  end
end

local function send(pane, command, opts)
  if opts.interrupt_before then
    if run({ "send-key", "-b", pane.block_id, "ctrl+c" }) == nil then
      return
    end
  end

  if opts.clear_before then
    if run({ "send", "-b", pane.block_id }, " clear\r") == nil then
      return
    end
  end

  -- stdin avoids shell quoting, argv parsing, and keyboard-layout translation of test commands.
  run({ "send", "-b", pane.block_id }, " " .. command .. "\r")
end

function M.run_in_pane(command, opts)
  local panes = M.get_panes()
  if panes == nil then
    return
  end

  for _, pane in ipairs(panes) do
    if pane.block_id == target_block_id then
      send(pane, command, opts or {})
      return
    end
  end

  -- Re-select if the target was closed or moved to another window, even if pane counts match.
  target_block_id = nil
  select_pane(panes, function(pane)
    send(pane, command, opts or {})
  end)
end

return M
