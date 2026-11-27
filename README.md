# PureGrid

Lightweight, zero-dependency, pixel-perfect screen alignment grid addon for **World of Warcraft Forever**.

Unlike Blizzard's Edit Mode grid—which only appears while Edit Mode is open—**PureGrid** can be toggled on or off in any situation to help align frames, addons, and UI layouts cleanly.

## Features

- **Pixel-Perfect & Symmetrical:** Grid lines radiate symmetrically from the exact center of the screen and align cleanly to physical screen pixels at any resolution or UI scale (`8–256 px` spacing with 1-click `8/16/32/64 px` presets, `1–4 px` thickness, `10%–100%` opacity, customizable Strata layer).
- **Major / Minor Grid Lines:** Accents every Nth line (every 5th line by default, customizable `2–16` or toggleable off) for effortless visual counting.
- **Independent Center Crosshairs & Crosshair-Only Mode:** Vertical and horizontal center lines with their own thickness, opacity, and color — plus a **Center Crosshair-Only** mode to hide the repeating grid.
- **Floating Quick-Bar & Live Cursor Offset HUD:** Sleek minimalist dark-glass draggable toolbar shown only while the grid is visible (with mousewheel stepping, Right-Click reset, and guide controls), plus an optional live cursor `(X, Y)` pixel offset readout from screen center.
- **Mirrored Custom Guide Lines & Reference Guides:** Drop up to 8 custom vertical/horizontal guide lines with live symmetrical mirroring (`±X` / `±Y`) and draggable on-screen handles, plus optional Rule of Thirds (`33% / 66%`) or Quarters (`25% / 75%`) reference lines.
- **Blizzard Edit Mode Integration:** Optional **Auto-Show in Blizzard Edit Mode**, cleanly suppressing Blizzard's coarse Edit Mode grid via `SetAlpha(0)` (zero taint) so two grids never stack.
- **Snap-on-Drop (ON by default while grid is visible):** Automatically snaps non-protected movable addon frames to the nearest grid line on release (`Edges Only` default, `Nearest Edge or Center`, or `Center Only`) with gold flash feedback (hold `Shift` to bypass; Blizzard Edit Mode frames are skipped to avoid combat taint).
- **Toggleable Anywhere:** Addon Compartment (enabled by default, toggleable in Settings), optional movable/lockable Minimap button, native Keybinding (`Options → Keybindings → AddOns → PureGrid → Toggle Grid`), and `/puregrid` slash commands.
- **Combat-Safe & Zero External Dependencies:** Automatically hides in combat by default (or enable **Keep Grid Visible in Combat**). Pure Lua + native Blizzard APIs only, zero idle `OnUpdate` overhead.

## Slash Commands

- `/puregrid` — Open PureGrid Settings
- `/puregrid toggle` / `on` / `off` — Toggle, show, or hide the grid
- `/puregrid <8-256>` — Set grid spacing directly (e.g. `/puregrid 32`)
- `/puregrid alpha <10-100>` — Set grid opacity directly (e.g. `/puregrid alpha 25`)
- `/puregrid crosshair` — Toggle Center Crosshair-Only mode
- `/puregrid snap` — Toggle Snap-on-Drop for addon frames
- `/puregrid guides` — Unlock or lock custom guide drag handles
- `/puregrid reset` — Reset Minimap button & Quick-Bar positions
- `/puregrid help` — Print command summary

## Installation

Place the `PureGrid` folder inside:
```text
World of Warcraft\_forever_\Interface\AddOns\PureGrid
```

## License

MIT License — Copyright (c) 2026 WorthyPenguin. See [LICENSE](LICENSE).
