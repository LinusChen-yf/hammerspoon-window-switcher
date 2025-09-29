# Hammerspoon Fuzzy Window Switcher

This Hammerspoon configuration turns the built-in chooser into a lightweight fuzzy window switcher, letting you jump to any visible standard window by typing flexible fragments of the window title and the owning app name.

## Features
- Fuzzy matching across both window titles and application names, in any order.
- Live ranking as you type so the best matches stay on top.
- Uses the app icon for quick visual recognition.

## Requirements
- macOS with [Hammerspoon](https://www.hammerspoon.org/) installed.

## Installation
1. Clone or download this repository.
2. Copy `init.lua` into your Hammerspoon config directory (usually `~/.hammerspoon/`).
3. Reload Hammerspoon via the menu bar icon or by running `hs.reload()` in the Hammerspoon console.

## Usage
- Press `F1` to toggle the chooser. (You can change the hotkey in `init.lua` by editing the `hs.hotkey.bind` call near the bottom.)
- Start typing any characters that appear in the target window title or its application name. Order does not matter.
- Use the arrow keys or continue typing to narrow the list, then hit `Return` to focus the highlighted window.

## Customization Tips
- Adjust the chooser size by modifying `.rows(10)` or `.width(30)` on the chooser definition.
- Tweak the fuzzy scoring weights inside the `fuzzyScore` function if you prefer different ranking behavior.
- Extend `buildSearchKeys` to add more aliases (for example, custom abbreviations for specific apps).
