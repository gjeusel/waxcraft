-- Enables the `hs` CLI, used by `just hammerspoon-check` to reload and inspect this config.
require("hs.ipc")

-- (ctrl + cmd + R) → Reload Hammerspoon config
hs.hotkey.bind({ "cmd", "ctrl" }, "R", function()
  hs.alert.show("🔨 Hammerspoon Config Reload", {}, hs.screen.primaryScreen())
  -- hs.reload() tears down this Lua state; load errors are reported in the Console.
  hs.timer.doAfter(1, hs.reload)
end)

-- Retain event taps, filters, timers, and screen watchers for the lifetime of this config.
-- Start each module in isolation: one failing module must not disable the others.
hammerspoonModules = {}
hammerspoonModuleErrors = {}
for _, name in ipairs({
  "macshot",
  "silent-chrome",
  "browser-popups",
  "slack-sharing",
  "offscreen-rescue",
  "aerospace-refresh",
}) do
  local ok, result = xpcall(function()
    return require(name).start()
  end, debug.traceback)
  if ok then
    hammerspoonModules[name] = result
  else
    hammerspoonModuleErrors[name] = result
    hs.printf("Could not start Hammerspoon module %s: %s", name, result)
    hs.alert.show("❌ Hammerspoon module " .. name .. " failed to start", 4)
  end
end
