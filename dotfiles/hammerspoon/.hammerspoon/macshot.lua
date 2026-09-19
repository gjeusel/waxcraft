local function start()
  local macshotBundleID = "com.sw33tlie.macshot.macshot"
  local macshotCopyGeneration = 0

  -- Observe the original keystroke instead of intercepting and synthesizing Cmd-C.
  local macshotCopyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
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

  return { copyWatcher = macshotCopyWatcher }
end

return { start = start }
