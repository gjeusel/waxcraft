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
  local initialWindows = hs.window.allWindows()
  for _, window in ipairs(initialWindows) do
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

  local slackMainTitles = { "%- Slack$", "%- Slack %[principal%]$", "%- Slack %[main%]$" }
  local slackSharingSession
  local slackMainWindowRestoreTimers = {}
  local slackMainWindowFilter = hs.window.filter.new(false):setAppFilter("Slack", {
    allowTitles = slackMainTitles,
  })

  local function isSlackMainWindow(window)
    local app = window and window:application()
    if not app or app:bundleID() ~= "com.tinyspeck.slackmacgap" then
      return false
    end

    for _, pattern in ipairs(slackMainTitles) do
      if (window:title() or ""):match(pattern) then
        return true
      end
    end

    return false
  end

  local function routeRestoredSlackWindow(windowId, session, attemptsLeft)
    local window = hs.window.get(windowId)
    if slackSharingSession ~= session or not isSlackMainWindow(window) then
      return
    end

    local function completed(exitCode, _, stderr)
      if exitCode == 0 or slackSharingSession ~= session then
        return
      end
      -- AeroSpace can take a moment to rediscover an unminimized window.
      if attemptsLeft > 1 then
        hs.timer.doAfter(0.1, function()
          routeRestoredSlackWindow(windowId, session, attemptsLeft - 1)
        end)
      else
        hs.printf("Could not restore Slack to workspace 4: %s", stderr)
      end
    end

    local task = hs.task.new("/run/current-system/sw/bin/aerospace", completed, {
      "move-node-to-workspace",
      "--window-id",
      tostring(windowId),
      "4",
    })
    if not task or not task:start() then
      completed(-1, "", "could not start AeroSpace")
    end
  end

  local function restoreSlackMainWindow(window)
    local session = slackSharingSession
    local windowId = window:id()
    if
      not session
      or not windowId
      or session.restored[windowId]
      or slackMainWindowRestoreTimers[windowId]
      or not isSlackMainWindow(window)
      or not window:isMinimized()
    then
      return
    end

    -- Consume the restoration before scheduling it: later manual minimization must stay put.
    session.restored[windowId] = true
    slackMainWindowRestoreTimers[windowId] = hs.timer.doAfter(1, function()
      slackMainWindowRestoreTimers[windowId] = nil
      local mainWindow = hs.window.get(windowId)
      if
        slackSharingSession == session
        and isSlackMainWindow(mainWindow)
        and mainWindow:isMinimized()
      then
        mainWindow:unminimize()
        routeRestoredSlackWindow(windowId, session, 10)
      end
    end)
  end

  slackMainWindowFilter:subscribe({
    hs.window.filter.windowMinimized,
    hs.window.filter.windowTitleChanged,
    hs.window.filter.windowUnminimized,
    hs.window.filter.windowDestroyed,
  }, function(window, _, event)
    if event == hs.window.filter.windowUnminimized or event == hs.window.filter.windowDestroyed then
      local windowId = window:id()
      local timer = slackMainWindowRestoreTimers[windowId]
      if timer then
        timer:stop()
        slackMainWindowRestoreTimers[windowId] = nil
      end
      return
    end

    restoreSlackMainWindow(window)
  end)

  local function isSlackSharingBar(window)
    local app = window:application()
    local size = window:size()
    -- The sharing controls have a generic title; exclude full-size/loading Slack windows.
    return app
      and app:bundleID() == "com.tinyspeck.slackmacgap"
      and window:title() == "Slack"
      and size.h >= 30
      and size.h <= 140
      and size.w >= 300
      and size.w >= size.h * 3
  end

  local function positionSlackSharingBar(window)
    local windowId = window:id()
    local state = newWindowStates[windowId]
    -- Only position newly created IDs once; existing or manually moved bars must stay put.
    if not isSlackSharingBar(window) or not state or state.handled or state.positioning then
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
        or not isSlackSharingBar(bar)
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

  -- Reloading mid-share must not undo choices made before this listener started.
  for _, window in ipairs(initialWindows) do
    if isSlackSharingBar(window) and window:isVisible() then
      slackSharingSession = slackSharingSession or { restored = {}, bars = {} }
      slackSharingSession.bars[window:id()] = true
    end
  end
  if slackSharingSession then
    for _, window in ipairs(initialWindows) do
      if isSlackMainWindow(window) then
        slackSharingSession.restored[window:id()] = true
      end
    end
  end

  -- AeroSpace ignores this toolbar: position it on workspace 0's display, not in its window tree.
  -- It may remain visible when that display switches workspaces.
  local slackSharingBarFilter = hs.window.filter.new(false):setAppFilter("Slack", {
    allowTitles = "^Slack$",
    allowRoles = "*",
  })
  -- The toolbar is our share-session signal; minimization alone may be the user's choice.
  -- Coalesce AX events so either order (main minimized / toolbar created) works.
  local slackSharingBarDebounce = hs.timer.delayed.new(0.2, function()
    local bars = {}
    for _, window in ipairs(slackSharingBarFilter:getWindows()) do
      local app = window:application()
      local windowId = window:id()
      local knownBar = slackSharingSession and slackSharingSession.bars[windowId]
      -- Expanded controls can change shape without starting a new sharing session.
      if (knownBar or isSlackSharingBar(window)) and (window:isVisible() or app:isHidden()) then
        bars[windowId] = true
        positionSlackSharingBar(window)
      end
    end

    if next(bars) then
      slackSharingSession = slackSharingSession or { restored = {} }
      slackSharingSession.bars = bars
      for _, window in ipairs(slackMainWindowFilter:getWindows()) do
        restoreSlackMainWindow(window)
      end
    else
      slackSharingSession = nil
      for windowId, timer in pairs(slackMainWindowRestoreTimers) do
        timer:stop()
        slackMainWindowRestoreTimers[windowId] = nil
      end
    end
  end)
  slackSharingBarFilter:subscribe({
    hs.window.filter.windowAllowed,
    hs.window.filter.windowRejected,
    hs.window.filter.windowVisible,
    hs.window.filter.windowNotVisible,
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
