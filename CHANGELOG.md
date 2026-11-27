# Changelog

## v1.1.0

- **Major / Minor Grid Lines:** Every 5th line is now subtly accented by default (graph-paper style); interval (`2–16`) and toggle are configurable in Settings.
- **Floating Quick-Bar:** Sleek minimalist dark-glass draggable toolbar shown while the grid is active (matching PureFish's pill style, with mousewheel stepping, hairline dividers, active/disabled states, Right-Click reset, and 1-click `Clr` guides button).
- **Blizzard Edit Mode Integration:** Optional **Auto-Show Grid in Blizzard Edit Mode**, cleanly hiding Blizzard's coarse Edit Mode grid via `SetAlpha(0)` (zero taint) while PureGrid is active.
- **Mirrored Custom Guide Lines:** Add up to 8 custom vertical/horizontal guides with optional live symmetry mirroring (`±X` / `±Y`), draggable on-screen handles (`Shift` for 1px precision, `Alt/Middle-Click` to toggle mirror, `Right-Click` to delete), and customizable guide color.
- **Center Crosshair-Only Mode:** Hide repeating grid lines to show only center crosshairs (and active guides).
- **Live Cursor Center Offset HUD:** Optional readout showing live physical pixel offset `(X, Y)` from exact screen center `(0, 0)`.
- **Center & Major Line Opacity & Thickness:** Configure thickness (`1–4 px`) and opacity (`10%–100%`, default `50%`) for both center crosshairs and highlighted major lines together, independent of the minor grid (`10%` default).
- **Snap-on-Drop Upgrades:** Now **ON by default** (active only while grid is visible), added **Snap Mode** (`Edges Only` default, `Nearest Edge or Center`, `Center Only`), and a brief gold **Snap Flash** highlight on snapped grid lines.
- **Screen Reference Guides:** Optional Rule of Thirds (`33% / 66%`) and Quarters (`25% / 75%`) gold reference lines.
- **Quick Spacing Presets & Slash Shortcuts:** Updated default spacing to `16 px`, added 1-click preset pills (`8px`, `16px`, `32px`, `64px`) plus `/puregrid <8-256>`, `/puregrid alpha <10-100>`, `/puregrid crosshair`, `/puregrid snap`, `/puregrid guides`, and `/puregrid help`.

## v1.0.2

- Adjusted default Minimap button position (`211°`) to sit neatly alongside PureFade and avoid colliding with other popular addons' Minimap buttons.

## v1.0.1

- Increased default grid opacity from `10%` to `20%` for better visibility out of the box.

## v1.0.0

- Initial release of **PureGrid** for World of Warcraft Forever (`16001`).
- Pixel-perfect, center-out symmetrical screen alignment grid with crisp red vertical & horizontal center crosshairs (defaults: `8 px` spacing, `1 px` thickness, `10%` opacity).
- Toggleable anytime via Addon Compartment button (enabled by default, toggleable in Settings), optional movable/lockable Minimap button (disabled by default, with Reset Position), `/puregrid` slash commands, or native Keybindings (`Bindings.xml`).
- Configurable Grid Spacing (`8–256 px`), Line Thickness (`1–4 px`), Grid Opacity (`10%–100%`), Grid Layer (Strata), and custom Grid & Center line colors.
- Combat-safe auto-hide in combat by default, with an optional **Keep Grid Visible in Combat** toggle and **Remember Grid State Across Reloads** option.
- Optional taint-safe **Snap Addon Frames to Grid on Drop** (disabled by default; snaps non-protected movable addon frames to the nearest grid line while the grid is visible, hold `Shift` to place freely).
- Native Blizzard `Options → AddOns → PureGrid` UI with hover tooltips and Reset to Defaults confirmation dialog.
