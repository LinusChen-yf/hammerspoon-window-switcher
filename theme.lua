-- ============================================
-- Claude Theme Configuration
-- ============================================

local theme = {}

-- Helper function to convert RGB (0-255) to normalized RGB (0-1)
local function rgb(r, g, b, alpha)
  return {red = r/255, green = g/255, blue = b/255, alpha = alpha or 1.0}
end

-- Claude theme colors (from CSS variables)
theme.colors = {
  light = {
    background = rgb(250, 249, 245, 0.95),      -- --background
    foreground = rgb(61, 57, 41, 1.0),          -- --foreground
    subtext = rgb(131, 130, 125, 1.0),          -- --muted-foreground
    border = rgb(218, 217, 212, 1.0),           -- --border
    selected = rgb(233, 230, 220, 1.0),         -- --accent
    selectedText = rgb(40, 38, 27, 1.0),        -- --accent-foreground
    primary = rgb(201, 100, 66, 1.0),           -- --primary
    inputBg = rgb(237, 233, 222, 1.0)           -- --muted
  },
  dark = {
    background = rgb(38, 38, 36, 0.95),         -- --background
    foreground = rgb(195, 192, 182, 1.0),       -- --foreground
    subtext = rgb(183, 181, 169, 1.0),          -- --muted-foreground
    border = rgb(62, 62, 56, 1.0),              -- --border
    selected = rgb(26, 25, 21, 1.0),            -- --accent
    selectedText = rgb(245, 244, 238, 1.0),     -- --accent-foreground
    primary = rgb(217, 119, 87, 1.0),           -- --primary
    inputBg = rgb(27, 27, 25, 1.0)              -- --muted
  }
}

-- Detect system appearance
function theme.isDarkMode()
  local _, result = hs.osascript.applescript([[
    tell application "System Events"
      tell appearance preferences
        return (dark mode as boolean)
      end tell
    end tell
  ]])
  return result
end

-- Get current theme based on system appearance
function theme.getCurrent()
  return theme.isDarkMode() and theme.colors.dark or theme.colors.light
end

return theme
