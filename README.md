# PureGrid

Lightweight, zero-dependency, pixel-perfect screen alignment grid addon for **World of Warcraft Forever (`16001`)**.

Unlike Blizzard's Edit Mode grid—which only appears while Edit Mode is open—**PureGrid** can be toggled on or off in any situation to help align frames, addons, and UI layouts cleanly.

## Features

- **Pixel-Perfect & Symmetrical:** Grid lines radiate symmetrically from the exact center of the screen and align cleanly to physical screen pixels at any resolution or UI scale (`8–256 px` spacing, `1–4 px` thickness, `10%–100%` opacity, customizable Strata layer).
- **Crisp Red Center Crosshairs:** Vertical and horizontal center lines render cleanly above grid lines (customizable color).
- **Toggleable Anywhere:**
  - **Addon Compartment** (enabled by default, toggleable in Settings): Left-Click toggles the grid, Right-Click opens Settings.
  - **Optional Minimap Button** (disabled by default): Enable in Settings, drag around the Minimap rim, lock/unlock, or reset position with one click.
  - **Keybinding:** Bind a hotkey under `Options → Keybindings → AddOns → PureGrid → Toggle Grid`.
  - **Slash Commands:** `/puregrid` (Settings), `/puregrid toggle`, `/puregrid on`, `/puregrid off`, `/puregrid reset`.
- **Combat-Safe:** Automatically hides when entering combat and restores after combat ends (or enable **Keep Grid Visible in Combat** in Settings).
- **Optional Snap-on-Drop:** Enable **Snap Addon Frames to Grid on Drop** to snap non-protected movable addon frames to the nearest grid line on release while the grid is visible (hold `Shift` to bypass; Blizzard Edit Mode frames are skipped to avoid combat taint).
- **Native Blizzard Settings UI:** Clean `Options → AddOns → PureGrid` panel with hover tooltips and Reset to Defaults confirmation dialog.
- **Zero External Dependencies:** Pure Lua + native Blizzard APIs only (no Ace3 or LibStub), zero idle `OnUpdate` overhead.

## Installation

Place the `PureGrid` folder inside:
```text
World of Warcraft\_forever_\Interface\AddOns\PureGrid
```

## License

MIT License — Copyright (c) 2026 WorthyPenguin. See [LICENSE](LICENSE).
