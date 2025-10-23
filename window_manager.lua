-- ============================================
-- Window Management Logic
-- ============================================

local fuzzySearch = require("fuzzy_search")
local windowManager = {}

-- Cache for app icons
local appIconCache = {}

-- Helper: Safe window focus
local function safeFocusWindow(win)
  if not win then return false end
  local ok, result = pcall(function() return win:focus() end)
  return ok and result ~= nil
end

-- Helper: Attempt to focus a window
local function attemptFocus(win)
  if not win then return false end
  if win:isMinimized() then win:unminimize() end
  if not win:isVisible() then return false end
  return safeFocusWindow(win)
end

-- Get app icon from bundle ID
local function getAppIcon(bundleID)
  if not bundleID or bundleID == "" then return nil end
  local cached = appIconCache[bundleID]
  if cached == nil then
    cached = hs.image.imageFromAppBundle(bundleID) or false
    appIconCache[bundleID] = cached
  end
  return cached or nil
end

-- Normalize window title
local function normalizedTitle(rawTitle, appName)
  if rawTitle and rawTitle ~= "" then return rawTitle end
  return "[" .. (appName or "") .. "]"
end

-- Make unique app key
local function makeAppKey(app)
  if not app then return nil end
  local bundleID = app:bundleID()
  if bundleID and bundleID ~= "" then
    return "bundle:" .. bundleID
  end
  local name = app:name()
  if name and name ~= "" then
    return "name:" .. name
  end
  return nil
end

-- Resolve application from choice
local function resolveApplication(choice)
  if choice.bundleID then
    local app = hs.application.get(choice.bundleID)
    if app then return app end
  end
  if choice.subText then
    return hs.application.get(choice.subText)
  end
  return nil
end

-- Pick best window for an app
local function pickBestWindow(app, choice)
  if not app then return nil end
  local exactVisible, visibleFallback, exactAny
  for _, win in ipairs(app:allWindows()) do
    if win:isStandard() then
      local title = win:title()
      if win:isVisible() and title == choice.text then
        exactVisible = win
        break
      elseif win:isVisible() and not visibleFallback then
        visibleFallback = win
      elseif not exactAny and title == choice.text then
        exactAny = win
      end
    end
  end
  return exactVisible or visibleFallback or exactAny
end

-- Focus a choice (window or calculator result)
function windowManager.focusChoice(choice, onRefresh)
  if not choice then return end

  -- Calculator result
  if choice.calcResult then
    hs.pasteboard.setContents(choice.calcResult)
    hs.alert.show("Copied result: " .. choice.calcResult, 1)
    return
  end

  -- Try by window ID
  if choice.id then
    if attemptFocus(hs.window.get(choice.id)) then
      if onRefresh then onRefresh() end
      return
    end
  end

  -- Try by app and window title
  local app = resolveApplication(choice)
  local target = pickBestWindow(app, choice)

  if attemptFocus(target) then
    if onRefresh then onRefresh() end
    return
  end

  -- Just activate the app
  if app then
    app:activate()
    if onRefresh then onRefresh() end
    return
  end

  -- Launch the app
  if choice.subText then
    hs.application.launchOrFocus(choice.subText)
    if onRefresh then onRefresh() end
  end
end

-- Get all window choices
function windowManager.getWindowChoices()
  local choices, seenWindowIDs, seenApps = {}, {}, {}
  local fallbackByApp = {}

  local function addWindow(win, allowHidden)
    if not win then return end
    local windowID = win:id()
    if not windowID or seenWindowIDs[windowID] then return end
    if not win:isStandard() or win:isMinimized() then return end

    local visible = win:isVisible()
    if visible == false and not allowHidden then return end

    local app = win:application()
    if not app then return end

    local appName = app:name() or ""
    local title = normalizedTitle(win:title(), appName)
    local bundleID = app:bundleID()

    table.insert(choices, {
      text = title,
      subText = appName,
      id = windowID,
      bundleID = bundleID,
      image = getAppIcon(bundleID),
      searchKeys = fuzzySearch.buildSearchKeys(title, appName)
    })

    seenWindowIDs[windowID] = true
    local key = makeAppKey(app)
    if key then seenApps[key] = true end
  end

  -- Add visible windows first
  for _, win in ipairs(hs.window.visibleWindows()) do
    addWindow(win, false)
  end

  -- Add windows from current space
  for _, win in ipairs(hs.window.filter.defaultCurrentSpace:getWindows()) do
    if win then
      local id = win:id()
      local resolved = (id and hs.window.get(id)) or win
      local app = resolved and resolved:application()
      local key = makeAppKey(app)
      if resolved and key and not seenApps[key] then
        fallbackByApp[key] = fallbackByApp[key] or {}
        table.insert(fallbackByApp[key], resolved)
      end
    end
  end

  -- Add fallback windows
  for key, windows in pairs(fallbackByApp) do
    if not seenApps[key] then
      for _, win in ipairs(windows) do
        addWindow(win, true)
      end
    end
  end

  return choices
end

return windowManager
