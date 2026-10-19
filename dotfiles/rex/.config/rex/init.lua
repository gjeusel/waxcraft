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
rex.bind(prefix .. "r", "pane.split", { direction = "down" })

-- Tabs, the tmux windows (tmux: c, n, p, &, ",", 1..9 with base-index 1)
rex.bind(prefix .. "c", "client.tab.new")
rex.bind(prefix .. "n", "client.tab.next")
rex.bind(prefix .. "p", "client.tab.previous")
rex.bind(prefix .. "shift+7", "client.tab.close")
rex.bind(prefix .. ",", "client.tab.rename")

for index = 1, 9 do
  rex.bind(prefix .. index, "client.tab.goto", { index = index })
end

-- Panes (tmux: x, z, o, !, E, arrows, ctrl+arrows)
rex.bind(prefix .. "x", "pane.close")
rex.bind(prefix .. "shift+e", "pane.balance")
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
-- own splits, then calls Rex from the edge split (nvim/lua/wax/navigator.lua).

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

    local _, err = rex.session.focus_direction({ direction = direction, wrap = true })

    return err == nil
  end)
end

-- ---- Ghostty keybinds ----

-- cmd+enter types Return instead of toggling full screen.
rex.bind("cmd+enter", "pane.send_key", { key = "enter" })

-- ctrl+enter types Return instead of an encoded key (ESC[27;5;13~) that shells print as `5;13~`.
rex.bind("ctrl+enter", "pane.send_key", { key = "enter" })
