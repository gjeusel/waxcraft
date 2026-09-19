-- Chrome and automation tools can activate a window independently of AeroSpace's silent move.
-- Only undo focus taken by a newly created automation window, never later manual activation.
local function start()
  local windows = {}
  local inputGeneration = 0
  local lastFocusedWindow = hs.window.focusedWindow()

  -- Seed synchronously: window.filter can discover pre-existing windows asynchronously.
  for _, window in ipairs(hs.window.allWindows()) do
    local application = window:application()
    local windowId = window:id()
    if windowId and application and application:bundleID() == "com.google.Chrome" then
      windows[windowId] = { handled = true }
    end
  end

  local inputWatcher = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.otherMouseDown,
  }, function()
    inputGeneration = inputGeneration + 1
    return false
  end)
  inputWatcher:start()

  local function restoreFocus(windowId, state)
    if not state or state.handled or windows[windowId] ~= state then
      return false
    end
    if
      inputGeneration ~= state.inputGeneration or hs.timer.secondsSinceEpoch() > state.expiresAt
    then
      windows[windowId] = { handled = true }
      return false
    end

    local focusedWindow = hs.window.focusedWindow()
    if not state.automated or not focusedWindow or focusedWindow:id() ~= windowId then
      return false
    end

    -- Consume before focusing: focus notifications may be delivered recursively.
    windows[windowId] = { handled = true }
    local previous = state.previous
    if not previous:application() or not previous:id() or previous:isMinimized() then
      return false
    end

    previous:focus()
    lastFocusedWindow = previous
    return true
  end

  local function observeNewChromeWindow(application, windowId)
    windows[windowId] = { handled = true }
    if not lastFocusedWindow or lastFocusedWindow:id() == windowId then
      return
    end

    -- Several automation windows can appear before the first process lookup completes.
    local previousState = windows[lastFocusedWindow:id()]
    local previous = previousState and not previousState.handled and previousState.previous
      or lastFocusedWindow
    local state = {
      previous = previous,
      inputGeneration = inputGeneration,
      expiresAt = hs.timer.secondsSinceEpoch() + 2,
    }
    windows[windowId] = state
    hs.timer.doAfter(2, function()
      if windows[windowId] == state then
        windows[windowId] = { handled = true }
      end
    end)

    -- A debugger alone is not enough: require a dedicated profile too. This is a launch-flag
    -- heuristic, not proof of who owns the process; normal Chrome launches fail closed.
    local task = hs.task.new("/bin/ps", function(exitCode, stdout)
      if windows[windowId] ~= state then
        return
      end
      if exitCode ~= 0 then
        windows[windowId] = { handled = true }
        return
      end

      local command = " " .. stdout:gsub("%s+", " ") .. " "
      local dedicatedProfile = command:match("%s%-%-user%-data%-dir[=%s]%S+")
      local automationFlag = command:match("%s%-%-remote%-debugging%-port[=%s]%S+")
        or command:match("%s%-%-remote%-debugging%-pipe%s")
        or command:match("%s%-%-enable%-automation%s")
      if not dedicatedProfile or not automationFlag then
        windows[windowId] = { handled = true }
        return
      end

      state.automated = true
      restoreFocus(windowId, state)
    end, { "-ww", "-p", tostring(application:pid()), "-o", "command=" })
    if not task or not task:start() then
      windows[windowId] = { handled = true }
    end
  end

  local filter = hs.window.filter.new(true)
  filter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowFocused,
    hs.window.filter.windowDestroyed,
  }, function(window, _, event)
    local windowId = window:id()
    if not windowId then
      return
    end
    if event == hs.window.filter.windowDestroyed then
      windows[windowId] = nil
      if lastFocusedWindow and lastFocusedWindow:id() == windowId then
        lastFocusedWindow = nil
      end
      return
    end

    if event == hs.window.filter.windowCreated then
      local application = window:application()
      if
        application
        and application:bundleID() == "com.google.Chrome"
        and not windows[windowId]
      then
        observeNewChromeWindow(application, windowId)
      end
    elseif event == hs.window.filter.windowFocused then
      if not restoreFocus(windowId, windows[windowId]) then
        lastFocusedWindow = window
      end
    end
  end)

  return { filter = filter, inputWatcher = inputWatcher }
end

return { start = start }
