-- ============================================
-- Fuzzy Search and Filtering
-- ============================================

local fuzzySearch = {}

-- Build search keys for a window choice
function fuzzySearch.buildSearchKeys(title, appName)
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

-- Calculate fuzzy match score
function fuzzySearch.fuzzyScore(haystack, needle)
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

-- Try to evaluate as calculator expression
function fuzzySearch.tryCalculate(query)
  local sanitized = query:gsub("%s+", "")
  if sanitized:match("^[%d%+%-%*%/%(%)%.]+$") then
    local success, result = pcall(function() return load("return " .. sanitized)() end)
    if success and type(result) == "number" then
      return result
    end
  end
  return nil
end

-- Filter choices based on query
function fuzzySearch.applyFilter(query, choices)
  if not query or query == "" then
    return choices
  end

  local q = query:lower()
  local matches = {}

  -- Try calculator first
  local calcResult = fuzzySearch.tryCalculate(query)
  if calcResult then
    local calcString = tostring(calcResult)
    -- Try to get Calculator app icon
    local calcIcon = hs.image.imageFromAppBundle("com.apple.calculator")
    table.insert(matches, {
      choice = {
        text = "= " .. calcString,
        subText = "Calculator: " .. query,
        id = nil,
        searchKeys = {},
        calcResult = calcString,
        image = calcIcon
      },
      score = math.huge
    })
  end

  -- Fuzzy match on choices
  for _, choice in ipairs(choices) do
    local bestScore
    for _, key in ipairs(choice.searchKeys) do
      local score = fuzzySearch.fuzzyScore(key, q)
      if score and (not bestScore or score > bestScore) then
        bestScore = score
      end
    end
    if bestScore then
      table.insert(matches, { choice = choice, score = bestScore })
    end
  end

  -- Sort by score
  table.sort(matches, function(a, b)
    if a.score == b.score then
      return a.choice.text < b.choice.text
    end
    return a.score > b.score
  end)

  -- Extract choices
  local filtered = {}
  for _, item in ipairs(matches) do
    table.insert(filtered, item.choice)
  end
  return filtered
end

return fuzzySearch
