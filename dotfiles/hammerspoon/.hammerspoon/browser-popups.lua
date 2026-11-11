local aerospace = require("aerospace")

-- AeroSpace's on-window-detected rules see a window once, often before its final title. Route
-- browser DevTools and Google Meet popups whose title arrives late, once per new window ID.
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
  -- Chromium names normal windows "<tab> - <product>[ - <profile>]"; picture-in-picture popups omit
  -- the product name. Firefox and Safari do not implement Document Picture-in-Picture.
  local meetPopupProductNames = {
    ["com.brave.Browser"] = "Brave",
    ["com.google.Chrome"] = "Google Chrome",
  }
  local newWindowStates = {}

  local function startsWithTitleSeparator(text)
    return text:match("^[-:]") or text:match("^–") or text:match("^—")
  end

  local function isDevtoolsWindow(window)
    local application = window:application()
    if not application or not browserBundleIDs[application:bundleID()] then
      return false
    end

    local title = window:title() or ""
    for _, prefix in ipairs(devtoolsTitlePrefixes) do
      if title:sub(1, #prefix) == prefix then
        local suffix = title:sub(#prefix + 1):match("^%s*(.*)")
        if suffix == "" or startsWithTitleSeparator(suffix) then
          return true
        end
      end
    end

    return false
  end

  -- Google Meet's picture-in-picture popup takes the meeting tab title, e.g. "Meet – abc-defg-hij".
  local function isMeetPopupWindow(window)
    local application = window:application()
    local productName = application and meetPopupProductNames[application:bundleID()]
    if not productName then
      return false
    end

    local title = window:title() or ""
    local afterMeet = title:match("^Meet%s*(.*)")
    local isMeetTitle = afterMeet ~= nil and startsWithTitleSeparator(afterMeet)
    local hasProductSegment = (title .. " - "):find(" - " .. productName .. " - ", 1, true)

    return isMeetTitle and not hasProductSegment
  end

  local function isWorkspaceZeroPopup(window)
    return isDevtoolsWindow(window) or isMeetPopupWindow(window)
  end

  local function isBrowserWindow(window)
    local application = window:application()
    return application ~= nil and browserBundleIDs[application:bundleID()] == true
  end

  -- Track identity, not current workspace: title changes must never undo a later manual move.
  -- Seed directly from AX: window.filter can defer registering apps without a focused window,
  -- then emit windowCreated for their pre-existing windows after subscriptions have started.
  for _, window in ipairs(hs.window.allWindows()) do
    local windowId = window:id()
    if windowId and isBrowserWindow(window) then
      newWindowStates[windowId] = { handled = true }
    end
  end

  local filter = hs.window.filter.new(isBrowserWindow)
  filter:subscribe({
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
    if not state or state.handled or state.routing or not isWorkspaceZeroPopup(window) then
      return
    end

    state.routing = true
    aerospace.moveWindowToWorkspace(windowId, "0", function()
      local current = hs.window.get(windowId)
      return newWindowStates[windowId] == state and current and isWorkspaceZeroPopup(current)
    end, function(handled)
      state.routing = false
      state.handled = handled
    end)
  end)

  return { filter = filter }
end

return { start = start }
