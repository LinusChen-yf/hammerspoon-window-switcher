# Hammerspoon Fuzzy Window Switcher

A modern UI window switcher Hammerspoon script for macOS with fuzzy search and calculator functionality.

## Features
- **Fuzzy matching** across both window titles and application names, in any order
- **Live ranking** as you type so the best matches stay on top
- **Inline calculator**: type a math expression and the result appears instantly at the top
- **Claude theme** with automatic light/dark mode switching based on system appearance

## Requirements
- macOS with [Hammerspoon](https://www.hammerspoon.org/) installed

## Installation
1. Clone this repository to your Hammerspoon config directory:
   ```bash
   git clone https://github.com/LinusChen-yf/hammerspoon-window-switcher.git ~/.hammerspoon
   ```
2. Reload Hammerspoon via the menu bar icon or by running `hs.reload()` in the Hammerspoon console

## Usage
- Press `F1` to toggle the window switcher
- Start typing any characters that appear in the target window title or its application name
- Enter a basic math expression (e.g. `3*7+2`) to see the result at the top
- Use **arrow keys** to navigate, **Enter** to select, **ESC** or **F1** to close

## Customization

### Changing the Hotkey
Edit the hotkey binding in `init.lua`:
```lua
-- Change F1 to your preferred key
hs.hotkey.bind({}, "f1", toggleUI)

-- Examples:
-- Cmd+Space: hs.hotkey.bind({"cmd"}, "space", toggleUI)
-- Ctrl+Tab: hs.hotkey.bind({"ctrl"}, "tab", toggleUI)
```
