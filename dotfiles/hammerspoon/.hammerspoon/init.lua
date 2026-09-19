local screen_retina = hs.screen.primaryScreen()

-- (ctrl + cmd + R) → Reload Hammerspoon config
hs.hotkey.bind({ "cmd", "ctrl" }, "R", function()
  local alertId =
    hs.alert.show("🔨 Hammerspoon Config Reload", { stayActive = true }, screen_retina)
  -- Then reload after a small delay
  hs.timer.doAfter(1, function()
    hs.alert.closeSpecific(alertId)
    local ok, err = pcall(hs.reload)
    if not ok then
      hs.alert.show("❌ " .. err:match("([^\n]+)"), 4)
    end
  end)
end)

-- Retain event taps, filters, timers, and screen watchers for the lifetime of this config.
hammerspoonModules = {
  macshot = require("macshot").start(),
  silentChrome = require("silent-chrome").start(),
  windowRouting = require("window-routing").start(),
  offscreenRescue = require("offscreen-rescue").start(),
}
