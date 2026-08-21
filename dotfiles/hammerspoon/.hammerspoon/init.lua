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

local macshotBundleID = "com.sw33tlie.macshot.macshot"
local macshotCopyAndClose
macshotCopyAndClose = hs.hotkey.new({ "cmd" }, "C", function()
  local focusedWindow = hs.window.focusedWindow()
  local editorWindowID
  if focusedWindow and focusedWindow:title():match("^macshot Editor") then
    editorWindowID = focusedWindow:id()
  end

  macshotCopyAndClose:disable()
  hs.eventtap.keyStroke({ "cmd" }, "C", 0)
  macshotCopyAndClose:enable()

  hs.timer.doAfter(0.1, function()
    local currentWindow = hs.window.focusedWindow()
    if editorWindowID and currentWindow and currentWindow:id() == editorWindowID then
      currentWindow:close()
    end
  end)
end)

local function updateMacshotHotkey(application)
  if application and application:bundleID() == macshotBundleID then
    macshotCopyAndClose:enable()
  else
    macshotCopyAndClose:disable()
  end
end

updateMacshotHotkey(hs.application.frontmostApplication())

local appWatcher = hs.application.watcher.new(function(_, eventType, application)
  if eventType == hs.application.watcher.activated then
    updateMacshotHotkey(application)
  end
end)
appWatcher:start()
