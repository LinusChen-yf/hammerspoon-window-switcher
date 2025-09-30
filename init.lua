local chooser = hs.chooser.new(function(choice)
  if not choice then return end
  local win = hs.window.get(choice.id)
  if win then win:focus() end
end):rows(10):width(30):searchSubText(true)

local cachedChoices = {}

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
  local wins = hs.window.filter.defaultCurrentSpace:getWindows()
  local out = {}
  for _, w in ipairs(wins) do
    if w:isStandard() and w:isVisible() then
      local app = w:application()
      if app then
        local appName = app:name()
        local title = w:title()
        if title == "" then title = "[" .. appName .. "]" end
        table.insert(out, {
          text = title,
          subText = appName,
          id = w:id(),
          image = hs.image.imageFromAppBundle(app:bundleID()),
          searchKeys = buildSearchKeys(title, appName)
        })
      end
    end
  end
  return out
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

local function refreshChoices()
  cachedChoices = windowChoices()
  chooser:choices(cachedChoices)
end

chooser:queryChangedCallback(function(query)
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
    table.insert(matches, {
      choice = {
        text = "= " .. calcResult,
        subText = "Calculator: " .. query,
        id = nil,
        searchKeys = {}
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
end)

local function toggleChooser()
  if chooser:isVisible() then
    chooser:hide()
  else
    refreshChoices()
    chooser:query(""):show()
  end
end

hs.hotkey.bind({}, "f1", toggleChooser)
