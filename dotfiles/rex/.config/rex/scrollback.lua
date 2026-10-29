-- Tools for the focused pane's scrollback, bound after the prefix:
-- - ctrl+u/ctrl+d jump between shell prompts and enter the `jump` mode, where they keep jumping,
--   y copies the last command, and Escape, a or A leave.
-- - y>1 copies the last command and its output.
-- - space opens the scrollback in Neovim, a copy mode with vim motions and visual selection.
--
-- Rex drops the OSC 133 prompt marks from the text it formats, so pure's prompt delimits commands:
-- a blank line, the preprompt line (directory and git branch), then the `λ` line with the command,
-- where the active virtualenv's name comes first, as in `.venv λ`.

local M = {}

local terminal = "com.superlogical.terminal"

local function check(result, err)
  if result == nil then
    error(err, 0)
  end

  return result
end

-- The whole screen and scrollback, read in parts when larger than one reply (960 KiB).
local function scrollback(block_id)
  local args = { block_id = block_id, trim = true, unwrap = true, max_bytes = 983040 }
  local reply = check(rex.block.call(terminal, "format", args))
  local parts = { reply.content }
  local offset = #reply.content
  local eof = reply.id == nil
  while not eof do
    local part = check(rex.block.call(terminal, "blob_read", {
      block_id = block_id,
      id = reply.id,
      offset = offset,
      max_bytes = 983040,
    }))
    table.insert(parts, part.data)
    offset = offset + #part.data
    eof = part.eof
  end

  return table.concat(parts)
end

-- The index of the last character at or before `i` that isn't a newline.
local function trim_newlines(text, i)
  while i > 0 and text:byte(i) == 10 do
    i = i - 1
  end

  return i
end

-- The last command's prompt line and its output, or nil before the first command. Scans bytes
-- rather than splitting lines: long outputs overflow Lua's registry as tables of lines.
local function last_command(text)
  local previous, last
  local symbol = text:find("λ", 1, true)
  while symbol ~= nil do
    local line = symbol
    while line > 1 and text:byte(line - 1) ~= 10 and symbol - line <= 64 do
      line = line - 1
    end

    -- `λ` starts a prompt line, alone or after a virtualenv's name.
    local at_line_start = line == 1 or text:byte(line - 1) == 10
    local prefix = text:sub(line, symbol - 1)
    if at_line_start and (prefix == "" or prefix:find("^%S+ $")) then
      previous, last = last, line
    end

    symbol = text:find("λ", symbol + #"λ", true)
  end

  if last == nil then
    return nil
  end

  -- The last prompt is the one waiting for input when nothing follows it, else a running command.
  local stop = trim_newlines(text, #text)
  local after_prompt = text:find("\n", last, true)
  local waiting = after_prompt == nil or after_prompt > stop
  local first = last
  if waiting then
    first = previous
    if first == nil then
      return nil
    end

    -- Stop before the waiting prompt's preprompt line and the blank line above it.
    stop = last - 2
    while stop > first and text:byte(stop) ~= 10 do
      stop = stop - 1
    end

    stop = trim_newlines(text, stop)
  end

  return text:sub(first, stop) .. "\n"
end

-- Copy mode: Rex has no copy mode, nor actions to scroll or select, so this opens the scrollback in
-- Neovim, floating over the pane. The Neovim config sets it up: nvim/lua/wax/copy_mode.lua.

-- The Neovim config finds its colorschemes through WAXPATH, which only the interactive zsh exports:
-- derive it from the config's own path, as nvim/ in the waxcraft repository.
local waxpath = [[lua vim.env.WAXPATH = vim.fs.dirname(vim.fn.resolve(vim.fn.stdpath("config")))]]

-- The row of the block's cursor on its screen, from 1 at the top, or nil. The text format leaves
-- out the screen's blank rows below the cursor, but the escape sequences end with its position.
local function cursor_row(block_id)
  local args = { block_id = block_id, format = "vt", extra_cursor = true, max_bytes = 1 }
  local reply = check(rex.block.call(terminal, "format", args))
  local tail = reply.content
  if reply.id ~= nil then
    tail = check(rex.block.call(terminal, "blob_read", {
      block_id = block_id,
      id = reply.id,
      offset = math.max(0, reply.total - 32),
    })).data
  end

  return tonumber(tail:match("\27%[(%d+);%d+H$"))
end

-- Whether the block is a copy mode float.
local function is_copy_mode(block_id)
  for _, block in ipairs(check(rex.session.list_blocks({})).blocks) do
    if block.block_id == block_id then
      return block.label == "copy mode"
    end
  end

  return false
end

-- The block's rectangle in a layout, as fractions of the window, or nil if it isn't there.
local function find_rect(node, block_id)
  if node.block_id ~= nil then
    return node.block_id == block_id and node.rect or nil
  end

  return find_rect(node.split.before, block_id) or find_rect(node.split.after, block_id)
end

function M.define(prefix)
  -- prefix ctrl+u/ctrl+d jump to the previous or next prompt and enter the `jump` mode, where
  -- ctrl+u/ctrl+d keep jumping, as tmux's repeatable `bind -r`, and y copies the last command.
  -- Rex can't leave a mode when ctrl is released or after a timeout, so the mode is exclusive:
  -- other keys do nothing until Escape, a or A leaves it, rather than reaching the terminal while
  -- ctrl+u/ctrl+d stay captured. Few keys keep Rex's hints for the mode short.
  rex.mode("jump", { exclusive = true })

  rex.action({
    name = "prompt_jump",
    title = "Jump to Prompt and Keep Jumping",
    category = "View",
    args = { action = "string" },
    run = function(_, args)
      rex.client.queue(args.action)
      rex.client.queue("client.mode.enter", { name = "jump" })
    end,
  })

  for key, action in pairs({ u = "client.prompt.previous", d = "client.prompt.next" }) do
    rex.bind(prefix .. "ctrl+" .. key, "prompt_jump", { action = action })
    rex.bind("jump/ctrl+" .. key, action)
  end

  rex.bind("jump/a", "client.mode.exit")
  rex.bind("jump/shift+a", "client.mode.exit")

  -- The latest command, not the one jumped to: Rex doesn't tell Lua where the pane is scrolled.
  -- Leaves the `jump` mode when copying from it; outside a mode, the exit does nothing.
  rex.action({
    name = "copy_last_command",
    title = "Copy Last Command and Output",
    category = "Workflows",
    keywords = "yank clipboard output scrollback",
    run = function(ctx)
      local block_id = check(ctx.block_id, "no focused pane")
      local copied = check(last_command(scrollback(block_id)), "no command in the scrollback")
      local r = check(rex.exec({ "pbcopy" }, { stdin = copied, env = { LC_CTYPE = "UTF-8" } }))
      if not r.ok then
        error("pbcopy failed: " .. r.stderr, 0)
      end

      rex.client.queue("client.mode.exit")
    end,
  })

  rex.bind(prefix .. "y>1", "copy_last_command")
  rex.bind("jump/y", "copy_last_command")

  rex.action({
    name = "copy_mode",
    title = "Copy Mode (Scrollback in Neovim)",
    category = "Workflows",
    keywords = "copy yank select visual scrollback vim",
    run = function(ctx)
      local block_id = check(ctx.block_id, "no focused pane")

      -- In copy mode, the prefix's space quits it rather than opening copy mode over copy mode,
      -- whose floats would then cover the pane that keys go to. Neovim quits as with q, which
      -- refocuses the pane copy mode was opened from: ctrl+\ ctrl+n leaves any mode, then :qa!.
      if is_copy_mode(block_id) then
        check(rex.block.call(terminal, "write", { block_id = block_id, data = "\28\14:qa!\r" }))
        return
      end

      local view = check(rex.session.view({}))
      local window
      for _, candidate in ipairs(view.windows) do
        if candidate.window_id == view.active_window_id then
          window = candidate
        end
      end

      -- A zoomed pane fills the window.
      local bounds = window.zoomed_block_id == nil and find_rect(window.layers[1].layout, block_id)

      local row = tostring(cursor_row(block_id))
      local modes = check(rex.block.call(terminal, "modes", { block_id = block_id }))
      local alternate = tostring(modes.screen == "alternate")
      local size = check(rex.block.call(terminal, "size", { block_id = block_id }))
      local text = scrollback(block_id)

      -- Neovim deletes the file once read; delete it here should the float not open. mktemp creates
      -- it readable by the user only, as the scrollback can hold secrets.
      local made = check(rex.exec({ "mktemp", "/tmp/rex-scrollback.XXXXXX" }))
      if not made.ok then
        error("mktemp failed: " .. made.stderr, 0)
      end

      local path = made.stdout:gsub("%s+$", "")
      local file = check(io.open(path, "w"))
      file:write(text)
      file:close()

      local open = "lua require('wax.copy_mode').open({ path = %q, origin = %q, cursor_row = %s, "
        .. "alternate = %s })"
      open = open:format(path, block_id, row, alternate)

      local _, err = rex.session.new_layer({
        window_id = window.window_id,
        bounds = bounds or { 0, 0, 1, 1 },
        focus = true,
        layout = {
          block = {
            flavor = terminal .. ".shell",
            label = "copy mode",
            options = {
              command = { "nvim", "-n", "--cmd", waxpath, "-c", open },
              -- Started at the pane's size rather than 80x24, Neovim positions the text in a
              -- window that has the pane's rows, not before the app resizes it.
              size = { columns = size.columns, rows = size.rows },
            },
          },
        },
      })
      if err ~= nil then
        os.remove(path)
        error(err, 0)
      end
    end,
  })

  rex.bind(prefix .. "space", "copy_mode")
end

return M
