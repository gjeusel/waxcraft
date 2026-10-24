-- Rex configuration, modeled on the tmux and ghostty packages of these dotfiles.
--
-- Apply changes with `rex config reload`, check them with `rex config check` and `rex keymap`.
-- Docs: https://www.superlogical.com/rex/docs
--
-- Font, cursor, padding and the Option key live in the app's Settings, not in this file. Ghostty
-- equivalents: Hack Nerd Font Mono 18, block cursor without blink, Option not used as Alt.

local terminal = "com.superlogical.terminal"
local config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/rex"

-- ---- Theme ----

rex.action({
  name = "theme_nord",
  title = "Apply Nord Theme",
  category = "View",
  keywords = "theme nord ghostty colors",
  run = function()
    rex.client.queue("client.theme.import", { path = config_dir .. "/themes/nord" })
  end,
})

-- ---- Sessions (tmuxp) ----

require("sessions").define(config_dir .. "/sessions")

-- ---- Prefix (tmux: prefix C-q) ----
-- ctrl+q starts every sequence below; press it twice to send ctrl+q to the terminal (send-prefix).

local prefix = "ctrl+q>"

rex.bind(prefix .. "ctrl+q", "pane.send_key", { key = "ctrl+q" })

-- Splits (tmux: prefix e / r)
rex.bind(prefix .. "e", "pane.split", { direction = "right" })
rex.bind(prefix .. "shift+e", "pane.split", { direction = "left" })
rex.bind(prefix .. "r", "pane.split", { direction = "down" })
rex.bind(prefix .. "shift+r", "pane.split", { direction = "up" })

-- Tabs, the tmux windows (tmux: c, n, p, &, ",", 1..9 with base-index 1)
rex.bind(prefix .. "c", "client.tab.new")
rex.bind(prefix .. "n", "client.tab.next")
rex.bind(prefix .. "p", "client.tab.previous")
rex.bind(prefix .. "shift+7", "client.tab.close")
rex.bind(prefix .. ",", "client.tab.rename")

for index = 1, 9 do
  rex.bind(prefix .. index, "client.tab.goto", { index = index })
end

-- Panes (tmux: x, z, o, !, arrows, ctrl+arrows; = balances, as tmux E does)
rex.bind(prefix .. "x", "pane.close")
rex.bind(prefix .. "=", "pane.balance")
rex.bind(prefix .. "z", "pane.zoom")
rex.bind(prefix .. "o", "pane.focus_next")
rex.bind(prefix .. "shift+1", "pane.move_to_new_tab")

for _, direction in ipairs({ "left", "right", "up", "down" }) do
  rex.bind(prefix .. direction, "pane.focus", { direction = direction })
  rex.bind(prefix .. "ctrl+" .. direction, "pane.resize", { direction = direction })
end

-- Sessions (tmux: s, $, (, ))
rex.bind(prefix .. "s", "session.switch")
rex.bind(prefix .. "shift+4", "session.rename")
rex.bind(prefix .. "shift+9", "session.previous")
rex.bind(prefix .. "shift+0", "session.next")

-- ---- Pane navigation (tmux: christoomey/vim-tmux-navigator) ----
-- ctrl+h/j/k/l move between panes, unless the focused terminal runs a program that uses these keys
-- itself: the key then reaches it, mirroring the plugin's `is_vim` check. Neovim moves between its
-- own splits, then runs the `navigate` action from the edge split (nvim/lua/wax/navigator.lua).

-- Among several panes on that side, Rex focuses the topmost; like tmux, prefer the one used last.
-- Rex reports only each window's focused pane, so the history is the panes `navigate` left.
local last_used = {}
local uses = 0

local function leaves(node, acc)
  if node.block_id ~= nil then
    table.insert(acc, node)
  else
    leaves(node.split.before, acc)
    leaves(node.split.after, acc)
  end

  return acc
end

-- The pane bordering `from` on the `direction` side that was used last, if any was.
local function last_used_beside(window, from, direction)
  local panes = leaves(window.layers[1].layout, {})
  local origin
  for _, pane in ipairs(panes) do
    if pane.block_id == from then
      origin = pane.rect
    end
  end

  if origin == nil then
    return nil
  end

  local x, y, w, h = unpack(origin)
  local eps = 1e-3
  local horizontal = direction == "left" or direction == "right"
  local best, best_use = nil, 0
  for _, pane in ipairs(panes) do
    local px, py, pw, ph = unpack(pane.rect)
    local touches = (direction == "left" and math.abs(px + pw - x) < eps)
      or (direction == "right" and math.abs(x + w - px) < eps)
      or (direction == "up" and math.abs(py + ph - y) < eps)
      or (direction == "down" and math.abs(y + h - py) < eps)
    local overlaps = horizontal and (py < y + h - eps and py + ph > y + eps)
      or (not horizontal and px < x + w - eps and px + pw > x + eps)
    local use = last_used[pane.block_id] or 0
    if touches and overlaps and use > best_use then
      best, best_use = pane.block_id, use
    end
  end

  return best
end

rex.action({
  name = "navigate",
  title = "Focus Pane in Direction",
  args = { direction = "string" },
  run = function(ctx, args)
    local view = assert(rex.session.view({}))
    local window
    for _, candidate in ipairs(view.windows) do
      if candidate.window_id == view.active_window_id then
        window = candidate
      end
    end

    local from = ctx.block_id or window.focused_block_id
    uses = uses + 1
    last_used[from] = uses

    -- From a zoomed pane, focus_direction unzooms first, as tmux's select-pane does.
    local target = window.zoomed_block_id == nil and last_used_beside(window, from, args.direction)
    local _, err
    if target then
      _, err = rex.session.focus_block({ block_id = target })
    else
      _, err = rex.session.focus_direction({ direction = args.direction, wrap = true })
    end

    if err ~= nil then
      error(err, 0)
    end
  end,
})

local vim_like =
  { vim = true, nvim = true, view = true, vimdiff = true, nvimdiff = true, fzf = true }

local function runs_vim_like(block_id)
  local process = rex.block.call(terminal, "process", { block_id = block_id })
  local foreground = process and process.foreground
  if foreground == nil then
    return false
  end

  -- Nix wraps programs as `.nvim-wrapped`.
  local name = foreground.name:gsub("^%.", ""):gsub("%-wrapped$", "")

  return vim_like[name] == true
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function(ctx)
    if runs_vim_like(ctx.block_id) then
      return false
    end

    local _, err = rex.invoke("navigate", { direction = direction })

    return err == nil
  end)
end

-- ---- Ghostty keybinds ----

-- cmd+enter types Return instead of toggling full screen.
rex.bind("cmd+enter", "pane.send_key", { key = "enter" })

-- ctrl+enter types Return instead of an encoded key (ESC[27;5;13~) that shells print as `5;13~`.
rex.bind("ctrl+enter", "pane.send_key", { key = "enter" })

-- cmd+up/down scroll to the previous or next shell prompt, as Ghostty's jump_to_prompt. Rex has no
-- line or page scroll action. Needs the OSC 133 prompt marks set up in zsh/init.zsh.
rex.bind("cmd+up", "client.prompt.previous")
rex.bind("cmd+down", "client.prompt.next")
