-- Tools for the focused pane's scrollback, bound after the prefix:
-- - ctrl+u/ctrl+d jump to the previous or next shell prompt, as cmd+up/cmd+down do when held.
-- - / searches the scrollback with Rex's find.
-- - y>1 copies the last command and its output.
-- - space opens a snapshot of the scrollback in Neovim, a copy mode with vim motions, search and
--   visual selection, where y copies and q quits. ctrl+h/j/k/l move to the pane beside and back.
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

-- The start of the prompt line whose `λ` is at `symbol`, or nil when it isn't a prompt: `λ` starts
-- the line, alone or after a virtualenv's name, below a preprompt line that follows a blank line or
-- starts the text. Output lines with a `λ` rarely follow the same pattern.
local function prompt_line(text, symbol)
  local line = symbol
  if line > 1 and text:byte(line - 1) == 32 then
    line = line - 1
    while line > 1 and not text:sub(line - 1, line - 1):find("%s") do
      line = line - 1
    end
  end

  local starts_line = line == 1 or text:byte(line - 1) == 10
  local has_word = line == symbol or line < symbol - 1
  if not starts_line or not has_word or line < 3 or text:byte(line - 2) == 10 then
    return nil
  end

  local preprompt = line - 2
  while preprompt > 0 and text:byte(preprompt) ~= 10 do
    preprompt = preprompt - 1
  end

  -- `preprompt` is the newline before the preprompt line, or 0 when that line starts the text.
  local after_blank = preprompt <= 1 or text:byte(preprompt - 1) == 10

  return after_blank and line or nil
end

-- The last command's prompt line and its output, or nil before the first command. `waiting` tells
-- whether the shell waits at the last prompt rather than runs its command. Scans bytes rather
-- than splitting lines: long outputs overflow Lua's registry as tables of lines.
local function last_command(text, waiting)
  local previous, last
  local symbol = text:find("λ", 1, true)
  while symbol ~= nil do
    local line = prompt_line(text, symbol)
    if line ~= nil then
      previous, last = last, line
    end

    symbol = text:find("λ", symbol + #"λ", true)
  end

  local first, stop = last, trim_newlines(text, #text)
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

  if first == nil then
    return nil
  end

  return text:sub(first, stop) .. "\n"
end

-- Whether the block's shell waits for a command: it is the foreground process, not a program.
local function shell_waiting(block_id)
  local process = check(rex.block.call(terminal, "process", { block_id = block_id }))
  local name = process.foreground and process.foreground.name or ""

  return ({ zsh = true, bash = true, sh = true, fish = true, nu = true })[name] == true
end

-- Copy mode: Rex has no copy mode, nor actions to scroll or select, so this opens a snapshot of the
-- scrollback in Neovim, floating over the pane and showing the text where the pane does.
-- nvim/lua/wax/copy_mode.lua sets Neovim up.

-- Copy mode's background, a shade darker than Nord's #2e3440, the terminal's in themes/nord, tells
-- it from the pane under it, which a float without a background of its own would also show through.
local background = "#2b303b"

-- Opening copy mode shows no blank float, nor a frame of Neovim before it is set up:
-- - The float first shows the pane's screen, $1, on copy mode's background, in one frame with
--   synchronized output (mode 2026), then holds the next frames until a UI's draw ends it.
-- - The app gives the float fewer rows than the pane, $3 as `rows columns`: its title bar takes
--   the top ones, so the float's rows line up with the pane's bottom ones. Printing every row of
--   the pane's screen keeps its bottom rows in view, whether the app resizes the float before or
--   after. Neovim waits for that size, up to 50ms, as resizing it would move the text.
-- - Neovim starts without a UI, running copy mode's setup, $2: a UI's first draw, as it clears the
--   screen, would end the hold before the text is there.
-- - The UI then attaches, and draws the text at once.
-- Without the user's init.lua or plugins, Neovim starts in a fifth of the time; its config stays on
-- the runtimepath for the copy mode module, filetype plugin and syntax. -i NONE keeps yanks out of
-- the shared history.
local launch = [[
printf '\033[?2026h%s\033[?2026l\033[?2026h' "$1"
waited=0
while [ "$(stty size)" = "$3" ] && [ "$waited" -lt 10 ]; do
  sleep 0.005
  waited=$((waited + 1))
done
size=$(stty size)
socket="${TMPDIR:-/tmp}/rex-copy-mode.$$.sock"
nvim --headless --listen "$socket" --cmd "set lines=${size% *} columns=${size#* }" \
  -u NORC --noplugin -i NONE -n -c "$2" &
while [ ! -S "$socket" ] && kill -0 $! 2>/dev/null; do
  sleep 0.005
done
exec nvim --remote-ui --server "$socket"
]]

-- The block's screen as escape sequences, and the row of its cursor from 1 at the top, or nil. The
-- escape sequences of the format end with the screen, rows separated by CRLF, then the cursor's
-- position.
local function screen(block_id, rows)
  local args = { block_id = block_id, format = "vt", extra_cursor = true, max_bytes = 1 }
  local reply = check(rex.block.call(terminal, "format", args))
  local tail, partial = reply.content, false
  if reply.id ~= nil then
    local offset = math.max(0, reply.total - 262144)
    tail = check(rex.block.call(terminal, "blob_read", {
      block_id = block_id,
      id = reply.id,
      offset = offset,
      max_bytes = 983040,
    })).data
    partial = offset > 0
  end

  local cursor = tail:match("\27%[%d+;%d+H$") or ""
  local rows_text = tail:sub(1, #tail - #cursor) .. "\r\n"
  local lines = {}
  for line in rows_text:gmatch("(.-)\r\n") do
    table.insert(lines, line)
  end

  -- Read from the middle of the format, the first line can start in an escape sequence.
  local first = math.max(partial and 2 or 1, #lines - rows + 1)

  return table.concat(lines, "\r\n", first), tonumber(cursor:match("(%d+);"))
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

-- The copy mode float over the block's pane in the window, if any, which navigating to the pane
-- focuses rather than the pane under it: init.lua's `navigate` action.
function M.copy_mode_over(window, block_id)
  local rect = window.zoomed_block_id == block_id and { 0, 0, 1, 1 }
    or find_rect(window.layers[1].layout, block_id)
  if not rect then
    return nil
  end

  local x, y = rect[1] + rect[3] / 2, rect[2] + rect[4] / 2
  for _, layer in ipairs(window.layers) do
    local block = layer.blocks and layer.blocks[1]
    local bx, by, bw, bh = unpack(layer.bounds)
    local covers = x > bx and x < bx + bw and y > by and y < by + bh
    if layer.kind == "floating" and block and block.label == "copy mode" and covers then
      return block.block_id
    end
  end

  return nil
end

function M.define(prefix)
  rex.bind(prefix .. "ctrl+u", "client.prompt.previous")
  rex.bind(prefix .. "ctrl+d", "client.prompt.next")
  rex.bind(prefix .. "/", "client.find.open")

  -- The latest command, not the one jumped to: Rex doesn't tell Lua where the pane is scrolled.
  rex.action({
    name = "copy_last_command",
    title = "Copy Last Command and Output",
    category = "Workflows",
    keywords = "yank clipboard output scrollback",
    run = function(ctx)
      local block_id = check(ctx.block_id, "no focused pane")
      local text = scrollback(block_id)
      local copied = last_command(text, shell_waiting(block_id))
      check(copied, "no command in the scrollback")
      local r = check(rex.exec({ "pbcopy" }, { stdin = copied, env = { LC_CTYPE = "UTF-8" } }))
      if not r.ok then
        error("pbcopy failed: " .. r.stderr, 0)
      end
    end,
  })

  rex.bind(prefix .. "y>1", "copy_last_command")

  rex.action({
    name = "copy_mode",
    title = "Copy Mode (Scrollback in Neovim)",
    category = "Workflows",
    keywords = "copy yank select visual scrollback vim",
    run = function(ctx)
      local block_id = check(ctx.block_id, "no focused pane")

      -- In copy mode, the prefix's space quits it rather than opening copy mode over copy mode,
      -- whose floats would then cover the pane that keys go to: ctrl+\ ctrl+n leaves any mode,
      -- then :qa!.
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
      local size = check(rex.block.call(terminal, "size", { block_id = block_id }))
      local modes = check(rex.block.call(terminal, "modes", { block_id = block_id }))
      local rows, row = screen(block_id, size.rows)
      local text = scrollback(block_id)

      -- Escape sequences paint the screen in copy mode's background, which every reset keeps,
      -- without the cursor, which Neovim shows once it draws.
      local r, g, b = background:match("#(%x%x)(%x%x)(%x%x)")
      local sgr = ("48;2;%d;%d;%d"):format(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
      rows = rows:gsub("\27%[0m", "\27[0;" .. sgr .. "m")
      local painted = ("\27[?25l\27[%sm\27[2J\27[H%s"):format(sgr, rows)

      -- mktemp creates the file readable by the user only, as the scrollback can hold secrets.
      local made = check(rex.exec({ "mktemp", "/tmp/rex-scrollback.XXXXXX" }))
      if not made.ok then
        error("mktemp failed: " .. made.stderr, 0)
      end

      local path = made.stdout:gsub("%s+$", "")
      local file = check(io.open(path, "w"))
      local written, write_err = file:write(text)
      local closed, close_err = file:close()
      if not written or not closed then
        os.remove(path)
        error("writing the scrollback failed: " .. tostring(write_err or close_err), 0)
      end

      local open = "require('wax.copy_mode').open({ path = %q, origin = %q, cursor_row = %s, "
        .. "alternate = %s, background = %q, rows = %d })"
      local alternate = tostring(modes.screen == "alternate")
      open = open:format(path, block_id, tostring(row), alternate, background, size.rows)
      local pane_size = ("%d %d"):format(size.rows, size.columns)

      local _, err = rex.session.new_layer({
        window_id = window.window_id,
        bounds = bounds or { 0, 0, 1, 1 },
        focus = true,
        layout = {
          block = {
            flavor = terminal .. ".shell",
            label = "copy mode",
            options = {
              command = { "sh", "-c", launch, "sh", painted, "lua " .. open, pane_size },
              -- Started at the pane's size rather than 80x24, Neovim positions the text in a
              -- window that has the pane's rows, not before the app resizes it.
              size = { columns = size.columns, rows = size.rows },
              -- Closes on any exit: Rex keeps a terminal whose program failed quickly, as :cq.
              exit = { quick_exit_threshold_ms = 0 },
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
