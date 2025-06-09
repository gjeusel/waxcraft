local screen_retina = hs.screen.primaryScreen()
local screen_secondary = screen_retina:next()

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

-- local map_ctrl_key_app = {
--   ["1"] = "Ghostty",
--   ["2"] = "Brave Browser",
--   ["3"] = "Firefox Developer Edition",
--   ["4"] = "Slack",
--   ["5"] = "Mimestream",
--   ["9"] = "Notion",
--   ["0"] = "Spotify",
-- }
-- for key, appname in pairs(map_ctrl_key_app) do
--   hs.hotkey.bind({ "ctrl", "cmd" }, key, function()
--     hs.application.launchOrFocus(appname)
--   end)
-- end

local function applicationWatcher(appName, eventType, appObject)
  if eventType == hs.application.watcher.activated then
    if appName == "Finder" then
      -- Bring all Finder windows forward when one gets activated
      appObject:selectMenuItem({ "Window", "Bring All to Front" })
    end
  end
end
local appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()
