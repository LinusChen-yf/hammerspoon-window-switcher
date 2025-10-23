-- ============================================
-- Claude Theme Custom Window Switcher
-- Main Entry Point
-- ============================================

-- Load modules
local theme = require("theme")
local ui = require("ui")
local windowManager = require("window_manager")
local fuzzySearch = require("fuzzy_search")

-- Global state
local state = {
  canvas = nil,
  eventTap = nil,
  visible = false,
  selectedIndex = 1,
  searchQuery = "",
  filteredChoices = {},
  cachedChoices = {},
  refreshTimer = nil,
  windowWatcher = nil
}

-- Schedule refresh with debouncing
local function scheduleRefresh(delay)
  if state.refreshTimer then
    state.refreshTimer:stop()
  end
  state.refreshTimer = hs.timer.doAfter(delay or 0.08, function()
    state.refreshTimer = nil
    if state.visible then
      refreshChoices()
    end
  end)
end

-- Apply search filter
local function applyFilter()
  state.filteredChoices = fuzzySearch.applyFilter(state.searchQuery, state.cachedChoices)
end

-- Refresh window choices
function refreshChoices()
  state.cachedChoices = windowManager.getWindowChoices()
  applyFilter()
  state.selectedIndex = 1
  if state.visible then
    ui.render(state.canvas, state.searchQuery, state.filteredChoices, state.selectedIndex)
  end
end

-- Keyboard event handling
local function handleKeyPress(event)
  if not state.visible then return false end

  local keyCode = event:getKeyCode()
  local chars = event:getCharacters()

  -- F1 or ESC to close
  if keyCode == 122 or keyCode == 53 then
    hideUI()
    return true
  end

  -- Enter to select
  if keyCode == 36 then
    local choice = state.filteredChoices[state.selectedIndex]
    hideUI()
    if choice then
      windowManager.focusChoice(choice, function()
        scheduleRefresh()
      end)
    end
    return true
  end

  -- Up arrow
  if keyCode == 126 then
    state.selectedIndex = math.max(1, state.selectedIndex - 1)
    ui.render(state.canvas, state.searchQuery, state.filteredChoices, state.selectedIndex)
    return true
  end

  -- Down arrow
  if keyCode == 125 then
    state.selectedIndex = math.min(#state.filteredChoices, state.selectedIndex + 1)
    ui.render(state.canvas, state.searchQuery, state.filteredChoices, state.selectedIndex)
    return true
  end

  -- Backspace
  if keyCode == 51 then
    if #state.searchQuery > 0 then
      state.searchQuery = state.searchQuery:sub(1, -2)
      applyFilter()
      state.selectedIndex = 1
      ui.render(state.canvas, state.searchQuery, state.filteredChoices, state.selectedIndex)
    end
    return true
  end

  -- Regular character input
  if chars and #chars > 0 then
    state.searchQuery = state.searchQuery .. chars
    applyFilter()
    state.selectedIndex = 1
    ui.render(state.canvas, state.searchQuery, state.filteredChoices, state.selectedIndex)
    return true
  end

  return false
end

-- Show UI
function showUI()
  if state.visible then return end

  -- Reset search state
  state.searchQuery = ""
  state.selectedIndex = 1
  
  -- Show UI immediately with cached data (instant response)
  applyFilter()
  ui.render(state.canvas, state.searchQuery, state.filteredChoices, state.selectedIndex)
  state.canvas:show()
  state.visible = true
  state.eventTap:start()
  
  -- Refresh data asynchronously to ensure it's up-to-date
  hs.timer.doAfter(0.001, function()
    if state.visible then
      refreshChoices()
    end
  end)
end

-- Hide UI
function hideUI()
  if not state.visible then return end

  if state.canvas then
    state.canvas:hide()
  end
  if state.eventTap then
    state.eventTap:stop()
  end
  state.visible = false

  -- Clear search query when hiding
  state.searchQuery = ""
  state.selectedIndex = 1
end

-- Toggle UI
local function toggleUI()
  if state.visible then
    hideUI()
  else
    showUI()
  end
end

-- Initialize UI components on startup for instant response
local function initializeComponents()
  -- Pre-create canvas
  state.canvas = hs.canvas.new({x = 0, y = 0, w = 100, h = 100})
  state.canvas:level("overlay")
  
  -- Pre-create event tap
  state.eventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, handleKeyPress)
  
  -- Initial cache load
  refreshChoices()
end

-- Hotkey binding
hs.hotkey.bind({}, "f1", toggleUI)

-- Window watcher - auto-refresh when windows change
state.windowWatcher = hs.window.filter.new()
state.windowWatcher:setCurrentSpace(true)
state.windowWatcher:subscribe({
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

-- Initialize on load
initializeComponents()
