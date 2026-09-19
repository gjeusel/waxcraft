local function start()
  -- AeroSpace emulates workspaces by parking hidden windows 1px inside the bottom-right corner and
  -- restores floating ones from the position/size it saved at hide time. Apps that resize, move, or
  -- recreate their own window (DaisyDisk, mini-players, ...) defeat that and come back offscreen.
  -- Only the focused workspace is checked, so deliberately parked windows are never touched.
  local function rescueOffscreenFloatingWindows()
    hs.task
      .new("/run/current-system/sw/bin/aerospace", function(exitCode, stdout)
        if exitCode ~= 0 then
          return
        end
        local ok, windows = pcall(hs.json.decode, stdout)
        if not ok or type(windows) ~= "table" then
          return
        end

        for _, entry in ipairs(windows) do
          local window = hs.window.get(entry["window-id"])
          -- Both APIs use the same 1-based NSScreen.screens ordering, not AeroSpace monitor IDs.
          local screen = hs.screen.allScreens()[entry["monitor-appkit-nsscreen-screens-id"]]
          if entry["window-layout"] == "floating" and window and screen then
            local frame = window:frame()
            local screenFrame = screen:frame()
            local x =
              math.max(screenFrame.x, math.min(frame.x, screenFrame.x + screenFrame.w - frame.w))
            local y =
              math.max(screenFrame.y, math.min(frame.y, screenFrame.y + screenFrame.h - frame.h))
            if math.abs(frame.x - x) > 1 or math.abs(frame.y - y) > 1 then
              window:setTopLeft({ x = x, y = y })
            end
          end
        end
      end, {
        "list-windows",
        "--workspace",
        "focused",
        "--format",
        "%{window-id} %{window-layout} %{monitor-appkit-nsscreen-screens-id}",
        "--json",
      })
      :start()
  end

  -- Triggered by exec-on-workspace-change in aerospace.toml (open -g hammerspoon://...).
  -- AeroSpace unhides asynchronously and apps may still be animating their frame: check twice.
  local rescueOffscreenTimers = {
    hs.timer.delayed.new(0.4, rescueOffscreenFloatingWindows),
    hs.timer.delayed.new(1.5, rescueOffscreenFloatingWindows),
  }
  local function scheduleOffscreenRescue()
    for _, timer in ipairs(rescueOffscreenTimers) do
      timer:start()
    end
  end
  hs.urlevent.bind("rescue-offscreen-windows", scheduleOffscreenRescue)

  -- Unplugging a display leaves floating windows at coordinates of a screen that no longer exists.
  local rescueOffscreenScreenWatcher = hs.screen.watcher.new(scheduleOffscreenRescue)
  rescueOffscreenScreenWatcher:start()

  return { timers = rescueOffscreenTimers, screenWatcher = rescueOffscreenScreenWatcher }
end

return { start = start }
