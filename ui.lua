-- ============================================
-- UI Rendering with Canvas
-- ============================================

local theme = require("theme")
local ui = {}

-- UI Configuration
local UI_CONFIG = {
  width = 700,
  maxVisibleRows = 8,
  rowHeight = 60,
  searchHeight = 50,
  padding = 12,
  iconSize = 40,
  cornerRadius = 8,
  fontSize = 15,
  subTextFontSize = 13
}

-- Render the UI
function ui.render(canvas, searchQuery, filteredChoices, selectedIndex)
  if not canvas then return end

  local currentTheme = theme.getCurrent()
  local screen = hs.screen.mainScreen():frame()
  local choices = filteredChoices
  local numRows = math.min(#choices, UI_CONFIG.maxVisibleRows)
  local listHeight = numRows * UI_CONFIG.rowHeight
  local totalHeight = UI_CONFIG.searchHeight + listHeight + UI_CONFIG.padding * 2

  local x = (screen.w - UI_CONFIG.width) / 2
  local y = screen.h * 0.3

  -- Set canvas frame
  canvas:frame({
    x = x,
    y = y,
    w = UI_CONFIG.width,
    h = totalHeight
  })

  -- Build all elements
  local elements = {}

  -- Background with rounded corners and shadow
  table.insert(elements, {
    type = "rectangle",
    action = "fill",
    fillColor = currentTheme.background,
    roundedRectRadii = { xRadius = UI_CONFIG.cornerRadius, yRadius = UI_CONFIG.cornerRadius },
    frame = { x = 0, y = 0, w = UI_CONFIG.width, h = totalHeight },
    shadow = {
      color = { alpha = 0.15 },
      blurRadius = 20,
      offset = { h = 0, w = 0 }
    }
  })

  -- Border
  table.insert(elements, {
    type = "rectangle",
    action = "stroke",
    strokeColor = currentTheme.border,
    strokeWidth = 1,
    roundedRectRadii = { xRadius = UI_CONFIG.cornerRadius, yRadius = UI_CONFIG.cornerRadius },
    frame = { x = 0, y = 0, w = UI_CONFIG.width, h = totalHeight }
  })

  -- Search input background
  table.insert(elements, {
    type = "rectangle",
    action = "fill",
    fillColor = currentTheme.inputBg,
    roundedRectRadii = { xRadius = 6, yRadius = 6 },
    frame = {
      x = UI_CONFIG.padding,
      y = UI_CONFIG.padding,
      w = UI_CONFIG.width - UI_CONFIG.padding * 2,
      h = UI_CONFIG.searchHeight - UI_CONFIG.padding
    }
  })

  -- Search text
  local searchBoxHeight = UI_CONFIG.searchHeight - UI_CONFIG.padding
  local textY = UI_CONFIG.padding + (searchBoxHeight - UI_CONFIG.fontSize) / 2
  table.insert(elements, {
    type = "text",
    text = searchQuery == "" and "Search windows..." or searchQuery,
    textColor = searchQuery == "" and currentTheme.subtext or currentTheme.foreground,
    textSize = UI_CONFIG.fontSize,
    textAlignment = "left",
    frame = {
      x = UI_CONFIG.padding * 2,
      y = textY,
      w = UI_CONFIG.width - UI_CONFIG.padding * 4,
      h = UI_CONFIG.fontSize + 4
    }
  })

  -- Draw list items
  local yOffset = UI_CONFIG.searchHeight + UI_CONFIG.padding

  for i = 1, numRows do
    local choice = choices[i]
    if not choice then break end

    local isSelected = (i == selectedIndex)
    local itemY = yOffset + (i - 1) * UI_CONFIG.rowHeight

    -- Selection background
    if isSelected then
      table.insert(elements, {
        type = "rectangle",
        action = "fill",
        fillColor = currentTheme.selected,
        roundedRectRadii = { xRadius = 6, yRadius = 6 },
        frame = {
          x = UI_CONFIG.padding,
          y = itemY,
          w = UI_CONFIG.width - UI_CONFIG.padding * 2,
          h = UI_CONFIG.rowHeight - 4
        }
      })
    end

    -- App icon
    if choice.image then
      table.insert(elements, {
        type = "image",
        image = choice.image,
        imageScaling = "scaleProportionally",
        frame = {
          x = UI_CONFIG.padding * 2,
          y = itemY + (UI_CONFIG.rowHeight - UI_CONFIG.iconSize) / 2,
          w = UI_CONFIG.iconSize,
          h = UI_CONFIG.iconSize
        }
      })
    end

    -- Main text
    table.insert(elements, {
      type = "text",
      text = choice.text or "",
      textColor = isSelected and currentTheme.selectedText or currentTheme.foreground,
      textSize = UI_CONFIG.fontSize,
      textAlignment = "left",
      frame = {
        x = UI_CONFIG.padding * 2 + UI_CONFIG.iconSize + UI_CONFIG.padding,
        y = itemY + 10,
        w = UI_CONFIG.width - UI_CONFIG.padding * 4 - UI_CONFIG.iconSize - UI_CONFIG.padding,
        h = 20
      }
    })

    -- Subtext
    if choice.subText then
      table.insert(elements, {
        type = "text",
        text = choice.subText,
        textColor = isSelected and currentTheme.selectedText or currentTheme.subtext,
        textSize = UI_CONFIG.subTextFontSize,
        textAlignment = "left",
        frame = {
          x = UI_CONFIG.padding * 2 + UI_CONFIG.iconSize + UI_CONFIG.padding,
          y = itemY + 32,
          w = UI_CONFIG.width - UI_CONFIG.padding * 4 - UI_CONFIG.iconSize - UI_CONFIG.padding,
          h = 18
        }
      })
    end
  end

  canvas:replaceElements(elements)
end

-- Get the UI frame and configuration
function ui.getFrame(canvas)
  return canvas:frame()
end

function ui.getConfig()
  return UI_CONFIG
end

-- Calculate which row index is at the given Y coordinate (relative to canvas)
function ui.getRowAtY(y, numVisibleRows)
  local listStartY = UI_CONFIG.searchHeight + UI_CONFIG.padding
  if y < listStartY then
    return nil
  end
  
  local relativeY = y - listStartY
  local rowIndex = math.floor(relativeY / UI_CONFIG.rowHeight) + 1
  
  if rowIndex >= 1 and rowIndex <= numVisibleRows then
    return rowIndex
  end
  return nil
end

return ui
