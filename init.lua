local chooser
local refreshChoices
local refreshTimer
local cachedChoices = {}
local appIconCache = {}

local function safeFocusWindow(win)
  if not win then return false end
  local ok, result = pcall(function() return win:focus() end)
  return ok and result ~= nil
end

local function scheduleRefresh(delay)
  if refreshTimer then
    refreshTimer:stop()
  end
  refreshTimer = hs.timer.doAfter(delay or 0.08, function()
    refreshTimer = nil
    if refreshChoices then
      refreshChoices()
    end
  end)
end

local function getAppIcon(bundleID)
  if not bundleID or bundleID == "" then return nil end
  local cached = appIconCache[bundleID]
  if cached == nil then
    cached = hs.image.imageFromAppBundle(bundleID) or false
    appIconCache[bundleID] = cached
  end
  return cached or nil
end

local function normalizedTitle(rawTitle, appName)
  if rawTitle and rawTitle ~= "" then return rawTitle end
  return "[" .. (appName or "") .. "]"
end

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

local function attemptFocus(win)
  if not win then return false end
  if win:isMinimized() then win:unminimize() end
  if not win:isVisible() then return false end
  return safeFocusWindow(win)
end

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

local function focusChoice(choice)
  if not choice then return end

  if choice.calcResult then
    hs.pasteboard.setContents(choice.calcResult)
    hs.alert.show("Copied result: " .. choice.calcResult, 1)
    return
  end

  if choice.id then
    if attemptFocus(hs.window.get(choice.id)) then
      scheduleRefresh()
      return
    end
  end

  local app = resolveApplication(choice)
  local target = pickBestWindow(app, choice)

  if attemptFocus(target) then
    scheduleRefresh()
    return
  end

  if app then
    app:activate()
    scheduleRefresh()
    return
  end

  if choice.subText then
    hs.application.launchOrFocus(choice.subText)
    scheduleRefresh()
  end
end

chooser = hs.chooser.new(focusChoice):rows(10):width(30):searchSubText(true)

local function buildSearchKeys(title, appName)
  -- Precompute combined keys in multiple orders so fuzzy search covers both title-first and app-first input.
  local combinations = {
    title .. " " .. appName,
    appName .. " " .. title,
    title,
    appName
  }
  local deduped, seen = {}, {}
  for _, key in ipairs(combinations) do
    local lowered = key:lower()
    if lowered ~= "" and not seen[lowered] then
      table.insert(deduped, lowered)
      seen[lowered] = true
    end
  end
  return deduped
end

local function windowChoices()
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
      searchKeys = buildSearchKeys(title, appName)
    })

    seenWindowIDs[windowID] = true
    local key = makeAppKey(app)
    if key then seenApps[key] = true end
  end

  for _, win in ipairs(hs.window.visibleWindows()) do
    addWindow(win, false)
  end

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

  for key, windows in pairs(fallbackByApp) do
    if not seenApps[key] then
      for _, win in ipairs(windows) do
        addWindow(win, true)
      end
    end
  end

  return choices
end

local function fuzzyScore(haystack, needle)
  haystack = haystack:lower()
  needle = needle:lower()
  local score, lastIndex, consecutive = 0, 0, 0
  for i = 1, #needle do
    local char = needle:sub(i, i)
    local found = haystack:find(char, lastIndex + 1, true)
    if not found then return nil end
    if found == lastIndex + 1 then
      consecutive = consecutive + 1
      score = score + 3 + consecutive
    else
      consecutive = 0
      local gap = found - lastIndex - 1
      score = score + 1 - math.min(gap * 0.1, 0.9)
    end
    lastIndex = found
  end
  return score - (lastIndex - #needle) * 0.01
end

local function applyQuery(query)
  if not query or query == "" then
    chooser:choices(cachedChoices)
    return
  end

  local q = query:lower()
  local matches = {}

  -- Try to evaluate as math expression
  local calcResult = nil
  local sanitized = query:gsub("%s+", "")
  if sanitized:match("^[%d%+%-%*%/%(%)%.]+$") then
    local success, result = pcall(function() return load("return " .. sanitized)() end)
    if success and type(result) == "number" then
      calcResult = result
    end
  end

  -- Add calculation result at top if valid
  if calcResult then
    local calcString = tostring(calcResult)
    table.insert(matches, {
      choice = {
        text = "= " .. calcString,
        subText = "Calculator: " .. query,
        id = nil,
        searchKeys = {},
        calcResult = calcString
      },
      score = math.huge
    })
  end

  for _, choice in ipairs(cachedChoices) do
    local bestScore
    for _, key in ipairs(choice.searchKeys) do
      local score = fuzzyScore(key, q)
      -- Track the highest scoring key per choice before adding it to the chooser list.
      if score and (not bestScore or score > bestScore) then
        bestScore = score
      end
    end
    if bestScore then
      table.insert(matches, { choice = choice, score = bestScore })
    end
  end

  table.sort(matches, function(a, b)
    if a.score == b.score then
      return a.choice.text < b.choice.text
    end
    return a.score > b.score
  end)

  local filtered = {}
  for _, item in ipairs(matches) do
    table.insert(filtered, item.choice)
  end
  chooser:choices(filtered)
end

refreshChoices = function()
  cachedChoices = windowChoices()
  local query = chooser:isVisible() and chooser:query()
  if query and query ~= "" then
    applyQuery(query)
  else
    chooser:choices(cachedChoices)
  end
end

chooser:queryChangedCallback(applyQuery)

local function toggleChooser()
  if chooser:isVisible() then
    chooser:hide()
  else
    chooser:choices(cachedChoices)
    chooser:query(""):show()
    scheduleRefresh(0.01)
  end
end

hs.hotkey.bind({}, "f1", toggleChooser)

local windowWatcher = hs.window.filter.new()
windowWatcher:setCurrentSpace(true)
windowWatcher:subscribe({
  hs.window.filter.windowCreated,
  hs.window.filter.windowDestroyed,
  hs.window.filter.windowFocused,
  hs.window.filter.windowUnfocused,
  hs.window.filter.windowTitleChanged,
  hs.window.filter.windowOnScreen,
  hs.window.filter.windowOffScreen,
}, function()
  scheduleRefresh(0.05)
end)

scheduleRefresh(0.02)
