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
local macshotCopyGeneration = 0

-- Observe the original keystroke instead of intercepting and synthesizing Cmd-C.
-- Keep the event tap reachable after init.lua returns.
macshotCopyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  if
    event:getKeyCode() ~= hs.keycodes.map.c
    or not flags.cmd
    or flags.alt
    or flags.ctrl
    or flags.shift
  then
    return false
  end

  local window = hs.window.focusedWindow()
  local application = window and window:application()
  if
    not application
    or application:bundleID() ~= macshotBundleID
    or not window:title():match("^macshot Editor")
  then
    return false
  end

  local editorWindowId = window:id()
  macshotCopyGeneration = macshotCopyGeneration + 1
  local generation = macshotCopyGeneration
  -- Image encoding is asynchronous. Never close on a timeout or a text/annotation-only copy.
  hs.pasteboard.callbackWhenChanged(5, function(changed)
    if not changed or generation ~= macshotCopyGeneration then
      return
    end
    local types = hs.pasteboard.contentTypes()
    local frontmostApplication = hs.application.frontmostApplication()
    if
      not hs.fnutils.contains(types, "public.png")
      or hs.fnutils.contains(types, "com.sw33tlie.macshot.annotations")
      or not frontmostApplication
      or frontmostApplication:bundleID() ~= macshotBundleID
    then
      return
    end

    -- Macshot's thumbnail can take focus after copying; close the source, not the focused window.
    local editorWindow = hs.window.get(editorWindowId)
    if editorWindow and editorWindow:title():match("^macshot Editor") then
      editorWindow:close()
    end
  end)
  return false
end)
macshotCopyWatcher:start()

local function routeRestoredSlackWindow(windowId, attemptsLeft)
  hs.task
    .new("/run/current-system/sw/bin/aerospace", function(exitCode, _, stderr)
      if exitCode == 0 then
        return
      end
      -- AeroSpace can take a moment to rediscover an unminimized window.
      if attemptsLeft > 1 then
        hs.timer.doAfter(0.1, function()
          routeRestoredSlackWindow(windowId, attemptsLeft - 1)
        end)
      else
        hs.printf("Could not restore Slack to workspace 4: %s", stderr)
      end
    end, { "move-node-to-workspace", "--window-id", tostring(windowId), "4" })
    :start()
end

-- Slack minimizes its main window when screen sharing. Include minimized windows in this filter.
-- Unminimizing can reinsert it on the current AeroSpace workspace; route it back without following.
-- Intentional minimization of the main Slack window is also undone, after a one-second delay.
local slackMainWindowRestoreTimers = {}
local slackMainWindowFilter = hs.window.filter.new(false):setAppFilter("Slack", {
  allowTitles = { "%- Slack %[principal%]$", "%- Slack %[main%]$" },
})
slackMainWindowFilter:subscribe({
  hs.window.filter.windowMinimized,
  hs.window.filter.windowTitleChanged,
}, function(window)
  local application = window:application()
  if
    application
    and application:bundleID() == "com.tinyspeck.slackmacgap"
    and window:isMinimized()
  then
    local windowId = window:id()
    if slackMainWindowRestoreTimers[windowId] then
      return
    end
    slackMainWindowRestoreTimers[windowId] = hs.timer.doAfter(1, function()
      slackMainWindowRestoreTimers[windowId] = nil
      local mainWindow = hs.window.get(windowId)
      local app = mainWindow and mainWindow:application()
      local title = mainWindow and mainWindow:title() or ""
      local isMainWindow = title:match("%- Slack %[principal%]$")
        or title:match("%- Slack %[main%]$")
      if
        app
        and app:bundleID() == "com.tinyspeck.slackmacgap"
        and isMainWindow
        and mainWindow:isMinimized()
      then
        mainWindow:unminimize()
        routeRestoredSlackWindow(windowId, 10)
      end
    end)
  end
end, true)

local slackSharingBarPositioning = {}
local function positionSlackSharingBar(window)
  local application = window:application()
  local size = window:size()
  local windowId = window:id()
  -- The sharing controls have the generic title "Slack"; exclude full-size/loading windows.
  if
    not application
    or application:bundleID() ~= "com.tinyspeck.slackmacgap"
    or window:title() ~= "Slack"
    or size.h < 30
    or size.h > 140
    or size.w < 300
    or size.w < size.h * 3
    or slackSharingBarPositioning[windowId]
  then
    return
  end

  slackSharingBarPositioning[windowId] = true
  local task = hs.task.new("/run/current-system/sw/bin/aerospace", function(exitCode, stdout)
    slackSharingBarPositioning[windowId] = nil
    local bar = hs.window.get(windowId)
    if exitCode ~= 0 or not bar or bar:title() ~= "Slack" then
      return
    end
    local ok, workspaces = pcall(hs.json.decode, stdout)
    if not ok or type(workspaces) ~= "table" then
      return
    end
    for _, workspace in ipairs(workspaces) do
      if workspace.workspace == "0" then
        -- Both APIs use the same 1-based NSScreen.screens ordering, not AeroSpace monitor IDs.
        local screen = hs.screen.allScreens()[workspace["monitor-appkit-nsscreen-screens-id"]]
        if not screen then
          return
        end
        local frame = screen:frame()
        local barFrame = bar:frame()
        local x = math.max(frame.x + 16, frame.x + frame.w - barFrame.w - 16)
        local y = frame.y + frame.h * 2 / 3 - barFrame.h / 2
        y = math.max(frame.y + 16, math.min(y, frame.y + frame.h - barFrame.h - 16))
        -- Preserve size and focus. The tolerance prevents our move event from causing a loop.
        if math.abs(barFrame.x - x) > 1 or math.abs(barFrame.y - y) > 1 then
          bar:setTopLeft({ x = x, y = y })
        end
        return
      end
    end
  end, {
    "list-workspaces",
    "--all",
    "--format",
    "%{workspace} %{monitor-appkit-nsscreen-screens-id}",
    "--json",
  })
  if not task:start() then
    slackSharingBarPositioning[windowId] = nil
  end
end

-- AeroSpace ignores this toolbar: position it on workspace 0's display, not in its window tree.
-- It may remain visible when that display switches workspaces.
local slackSharingBarFilter = hs.window.filter.new(false):setAppFilter("Slack", {
  allowTitles = "^Slack$",
  visible = true,
})
-- Coalesce move/resize and display-change bursts before launching an AeroSpace query.
local slackSharingBarDebounce = hs.timer.delayed.new(0.2, function()
  for _, window in ipairs(slackSharingBarFilter:getWindows()) do
    positionSlackSharingBar(window)
  end
end)
slackSharingBarFilter:subscribe({
  hs.window.filter.windowAllowed,
  hs.window.filter.windowMoved,
}, function()
  slackSharingBarDebounce:start()
end, true)

slackSharingBarScreenWatcher = hs.screen.watcher.new(function()
  slackSharingBarDebounce:start()
end)
slackSharingBarScreenWatcher:start()
