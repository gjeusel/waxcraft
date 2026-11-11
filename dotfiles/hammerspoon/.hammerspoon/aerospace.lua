-- Shared helpers for driving the AeroSpace CLI from Hammerspoon modules.
local binary = "/run/current-system/sw/bin/aerospace"

-- Hammerspoon stops a timer once it is garbage collected: keep pending retries referenced. A fired
-- retry must drop every reference to itself, or its registry-held callback keeps it alive forever.
local retryTimers = {} -- luacheck: ignore 241 (only written, on purpose)

-- Calls `callback(exitCode, stdout, stderr)` once, including when the task cannot start.
local function run(args, callback)
  local task = hs.task.new(binary, callback, args)
  if not task or not task:start() then
    callback(-1, "", "could not start AeroSpace")
  end
end

-- AeroSpace can lag behind macOS notifications for new or unminimized windows, so a failed move
-- is retried. `isCurrent()` revalidates the request before every attempt. `onDone(handled)`, if
-- given, receives true once the window moved or the retries ran out, false when cancelled.
local function moveWindowToWorkspace(windowId, workspace, isCurrent, onDone)
  onDone = onDone or function() end
  local attemptsLeft = 10

  local args = { "move-node-to-workspace", "--window-id", tostring(windowId), workspace }

  local function attempt()
    if not isCurrent() then
      onDone(false)
      return
    end

    run(args, function(exitCode, _, stderr)
      if exitCode == 0 then
        onDone(true)
        return
      end

      attemptsLeft = attemptsLeft - 1
      if attemptsLeft == 0 then
        hs.printf("Could not move window %s to workspace %s: %s", windowId, workspace, stderr)
        onDone(true)
        return
      end

      local timer
      timer = hs.timer.doAfter(0.1, function()
        retryTimers[timer] = nil
        timer = nil
        attempt()
      end)
      retryTimers[timer] = true
    end)
  end

  attempt()
end

-- AeroSpace's `monitor-appkit-nsscreen-screens-id` uses the same 1-based NSScreen.screens
-- ordering as hs.screen.allScreens(), not AeroSpace monitor IDs.
local function screenForEntry(entry)
  return hs.screen.allScreens()[entry["monitor-appkit-nsscreen-screens-id"]]
end

return {
  run = run,
  moveWindowToWorkspace = moveWindowToWorkspace,
  screenForEntry = screenForEntry,
}
