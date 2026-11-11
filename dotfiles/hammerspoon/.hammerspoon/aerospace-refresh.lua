local function start()
  local aerospaceBundleID = "bobko.aerospace"
  local screenCount = #hs.screen.allScreens()
  local relaunchTimer

  -- AeroSpace only runs on-window-detected once per window, so windows keep the workspace they
  -- were squeezed into when a display went away. Restarting it replays every rule from scratch.
  local function restartAerospace()
    -- The watcher also fires for resolution, arrangement, and Dock changes, and a wake from sleep
    -- can drop and re-add a display: only a settled change in the number of screens counts.
    local settledScreenCount = #hs.screen.allScreens()
    if settledScreenCount == screenCount then
      return
    end
    screenCount = settledScreenCount

    -- Not running means it was quit on purpose: leave it that way.
    local aerospace = hs.application.applicationsForBundleID(aerospaceBundleID)[1]
    if not aerospace then
      return
    end

    -- A graceful quit lets AeroSpace bring its hidden windows back on screen first.
    aerospace:kill()

    if relaunchTimer then
      relaunchTimer:stop()
    end

    -- Give up if it hangs on quit, so a later deliberate quit is never turned into a relaunch.
    local deadline = hs.timer.secondsSinceEpoch() + 10
    relaunchTimer = hs.timer.waitUntil(function()
      local hasQuit = #hs.application.applicationsForBundleID(aerospaceBundleID) == 0
      return hasQuit or hs.timer.secondsSinceEpoch() > deadline
    end, function()
      relaunchTimer = nil
      if #hs.application.applicationsForBundleID(aerospaceBundleID) == 0 then
        hs.application.launchOrFocusByBundleID(aerospaceBundleID)
      else
        hs.printf("AeroSpace did not quit within 10s: not relaunching it")
      end
    end, 0.2)
  end

  -- macOS reports a display change in several bursts while it rearranges the screens.
  local restartDebounce = hs.timer.delayed.new(2, restartAerospace)
  local screenWatcher = hs.screen.watcher.new(function()
    restartDebounce:start()
  end)
  screenWatcher:start()

  return { restartDebounce = restartDebounce, screenWatcher = screenWatcher }
end

return { start = start }
