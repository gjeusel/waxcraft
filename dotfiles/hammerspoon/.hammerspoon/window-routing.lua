local function start()
  local browserBundleIDs = {
    ["com.brave.Browser"] = true,
    ["com.google.Chrome"] = true,
    ["org.mozilla.firefox"] = true,
    ["org.mozilla.firefoxdeveloperedition"] = true,
    ["app.zen-browser.zen"] = true,
    ["com.apple.Safari"] = true,
  }
  local devtoolsTitlePrefixes = {
    "DevTools",
    "Developer Tools",
    "Outils de développement",
    "Outils pour les développeurs",
    "Web Inspector",
    "Inspecteur web",
  }
  local newWindowStates = {}

  local function isDevtoolsWindow(window)
    local application = window:application()
    if not application or not browserBundleIDs[application:bundleID()] then
      return false
    end

    local title = window:title() or ""
    for _, prefix in ipairs(devtoolsTitlePrefixes) do
      if title:sub(1, #prefix) == prefix then
        local suffix = title:sub(#prefix + 1):match("^%s*(.*)")
        if
          suffix == ""
          or suffix:match("^[-:]")
          or suffix:match("^–")
          or suffix:match("^—")
        then
          return true
        end
      end
    end

    return false
  end

  local function routeNewDevtoolsWindow(windowId, state, attemptsLeft)
    local window = hs.window.get(windowId)
    if newWindowStates[windowId] ~= state or not window or not isDevtoolsWindow(window) then
      state.routing = false
      return
    end

    local function completed(exitCode, _, stderr)
      if newWindowStates[windowId] ~= state then
        return
      end
      if exitCode == 0 then
        state.handled = true
        state.routing = false
      elseif attemptsLeft > 1 then
        -- Window creation/title notifications can precede AeroSpace's discovery of the ID.
        hs.timer.doAfter(0.1, function()
          routeNewDevtoolsWindow(windowId, state, attemptsLeft - 1)
        end)
      else
        state.handled = true
        state.routing = false
        hs.printf("Could not route DevTools window %s: %s", windowId, stderr)
      end
    end

    local task = hs.task.new("/run/current-system/sw/bin/aerospace", completed, {
      "move-node-to-workspace",
      "--window-id",
      tostring(windowId),
      "0",
    })
    if not task or not task:start() then
      completed(-1, "", "could not start AeroSpace")
    end
  end

  local function isTrackedWindow(window)
    local application = window:application()
    local bundleID = application and application:bundleID()
    return bundleID == "com.tinyspeck.slackmacgap" or browserBundleIDs[bundleID] == true
  end

  -- Track identity, not current workspace: title changes must never undo a later manual move.
  -- Seed directly from AX: window.filter can defer registering apps without a focused window,
  -- then emit windowCreated for their pre-existing windows after subscriptions have started.
  for _, window in ipairs(hs.window.allWindows()) do
    local windowId = window:id()
    if windowId and isTrackedWindow(window) then
      newWindowStates[windowId] = { handled = true }
    end
  end
  local newWindowFilter = hs.window.filter.new(isTrackedWindow)
  newWindowFilter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowTitleChanged,
    hs.window.filter.windowDestroyed,
  }, function(window, _, event)
    local windowId = window:id()
    if not windowId then
      return
    end
    if event == hs.window.filter.windowDestroyed then
      newWindowStates[windowId] = nil
      return
    end
    if event == hs.window.filter.windowCreated and not newWindowStates[windowId] then
      newWindowStates[windowId] = {}
    end

    local state = newWindowStates[windowId]
    if state and not state.handled and not state.routing and isDevtoolsWindow(window) then
      state.routing = true
      routeNewDevtoolsWindow(windowId, state, 10)
    end
  end)

  -- Slack's workspace rules run only at detection in AeroSpace; do not reapply them on restore.
  -- Slack minimizes its main window when screen sharing. Include minimized windows in this filter.
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
        end
      end)
    end
  end, true)

  local function positionSlackSharingBar(window)
    local application = window:application()
    local size = window:size()
    local windowId = window:id()
    local state = newWindowStates[windowId]
    -- Only position newly created IDs once; existing or manually moved bars must stay put.
    -- The sharing controls have the generic title "Slack"; exclude full-size/loading windows.
    if
      not application
      or application:bundleID() ~= "com.tinyspeck.slackmacgap"
      or window:title() ~= "Slack"
      or size.h < 30
      or size.h > 140
      or size.w < 300
      or size.w < size.h * 3
      or not state
      or state.handled
      or state.positioning
    then
      return
    end

    state.positioningAttempts = (state.positioningAttempts or 0) + 1
    if state.positioningAttempts > 10 then
      state.handled = true
      hs.printf("Could not position Slack sharing toolbar %s after 10 attempts", windowId)
      return
    end

    state.positioning = true
    local task = hs.task.new("/run/current-system/sw/bin/aerospace", function(exitCode, stdout)
      state.positioning = false
      local bar = hs.window.get(windowId)
      if
        newWindowStates[windowId] ~= state
        or exitCode ~= 0
        or not bar
        or bar:title() ~= "Slack"
      then
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
          state.handled = true
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
    if not task or not task:start() then
      state.positioning = false
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

  local slackSharingBarScreenWatcher = hs.screen.watcher.new(function()
    slackSharingBarDebounce:start()
  end)
  slackSharingBarScreenWatcher:start()

  return {
    newWindowFilter = newWindowFilter,
    slackMainWindowFilter = slackMainWindowFilter,
    slackMainWindowRestoreTimers = slackMainWindowRestoreTimers,
    slackSharingBarFilter = slackSharingBarFilter,
    slackSharingBarDebounce = slackSharingBarDebounce,
    slackSharingBarScreenWatcher = slackSharingBarScreenWatcher,
  }
end

return { start = start }
