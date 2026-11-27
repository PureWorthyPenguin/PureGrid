-- PureGrid: Defaults, constants, and WoW Forever (16001) safety helpers.
local _, ns = ...

-- Global keybinding header & label for Bindings.xml
BINDING_HEADER_PUREGRID = "PureGrid"
BINDING_NAME_PUREGRID_TOGGLE = "Toggle Grid"

-- Safe value helpers for WoW Forever (secret values & forbidden frames)
local issecretvalue = _G.issecretvalue

function ns.IsSecret(val)
	return issecretvalue ~= nil and issecretvalue(val) == true
end

function ns.SafeNumber(val)
	if type(val) ~= "number" or (issecretvalue and issecretvalue(val)) then
		return nil
	end
	return val
end

function ns.SafeBool(val)
	if issecretvalue and issecretvalue(val) then
		return false
	end
	return val and true or false
end

function ns.IsUsableFrame(obj)
	if type(obj) ~= "table" or type(obj.GetObjectType) ~= "function" then
		return false
	end
	if obj.IsForbidden and obj:IsForbidden() then
		return false
	end
	return true
end

function ns.DeepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local copy = {}
	for k, v in pairs(src) do
		copy[k] = ns.DeepCopy(v)
	end
	return copy
end

-- Grid layer (frame strata) choices
ns.STRATA_OPTIONS = {
	{ value = "BACKGROUND", label = "Background (Behind UI)" },
	{ value = "LOW",        label = "Low" },
	{ value = "MEDIUM",     label = "Medium" },
	{ value = "HIGH",       label = "High (Over Most UI)" },
	{ value = "DIALOG",     label = "Dialog (Topmost)" },
}

ns.STRATA_LABEL_BY_VALUE = {}
for _, opt in ipairs(ns.STRATA_OPTIONS) do
	ns.STRATA_LABEL_BY_VALUE[opt.value] = opt.label
end

-- Screen reference guide choices
ns.REFERENCE_GUIDE_OPTIONS = {
	{ value = "none",     label = "None" },
	{ value = "thirds",   label = "Rule of Thirds (33% / 66%)" },
	{ value = "quarters", label = "Quarters (25% / 75%)" },
}

ns.REFERENCE_GUIDE_LABEL_BY_VALUE = {}
for _, opt in ipairs(ns.REFERENCE_GUIDE_OPTIONS) do
	ns.REFERENCE_GUIDE_LABEL_BY_VALUE[opt.value] = opt.label
end

-- Snap-on-drop mode choices
ns.SNAP_MODE_OPTIONS = {
	{ value = "nearest", label = "Nearest Edge or Center" },
	{ value = "center",  label = "Center Only" },
	{ value = "edges",   label = "Edges Only" },
}

ns.SNAP_MODE_LABEL_BY_VALUE = {}
for _, opt in ipairs(ns.SNAP_MODE_OPTIONS) do
	ns.SNAP_MODE_LABEL_BY_VALUE[opt.value] = opt.label
end

-- Quick spacing presets (Settings pills & Quick-Bar stepping)
ns.SPACING_PRESETS = { 8, 16, 32, 64 }
ns.QUICKBAR_SPACING_STEPS = { 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256 }

ns.DEFAULT_MINIMAP_ANGLE = 211
ns.MAX_CUSTOM_GUIDES = 8

-- Default settings
function ns.BuildDefaultGeneral()
	return {
		-- Grid Appearance
		gridSize              = 16,       -- 8..256 px spacing between grid lines
		lineThickness         = 1,        -- 1..4 px physical pixel line thickness
		gridAlpha             = 0.10,     -- 0.10..1.00 opacity
		majorLineEnabled      = true,     -- Accent every Nth line
		majorLineInterval     = 5,        -- 2..16 (every 5th line by default)
		crosshairOnly         = false,    -- Hide repeating grid, show only center crosshairs
		strata                = "HIGH",   -- Frame strata
		-- Center Lines & Colors
		centerAlpha           = 0.50,     -- 0.10..1.00 independent center & major line opacity
		centerThickness       = 1,        -- 1..4 px independent center line thickness
		gridColor             = { r = 1.0, g = 1.0, b = 1.0 },
		centerColor           = { r = 1.0, g = 0.15, b = 0.15 },
		guideColor            = { r = 0.0, g = 0.9, b = 1.0 },
		-- Reference & Custom Guides
		referenceGuide        = "none",   -- "none", "thirds", "quarters"
		guides                = {},       -- up to 8: { axis = "V"|"H", offset = 200, mirror = true }
		-- Floating Quick-Bar & Cursor HUD
		showQuickBar          = true,
		quickBarPos           = nil,      -- { point, relPoint, x, y }
		showCursorCoords      = false,
		-- Behavior & Edit Mode
		keepInCombat          = false,    -- Auto-hide grid in combat when false
		rememberState         = false,    -- Restore grid visibility across reloads
		autoShowInEditMode    = false,    -- Automatically show PureGrid in Blizzard Edit Mode
		hideBlizzardEditGrid  = true,     -- Suppress Blizzard's Edit Mode grid while PureGrid is active
		snapToGrid            = true,     -- Snap non-protected addon frames to grid on drop
		snapMode              = "edges",  -- "nearest", "center", "edges"
		snapFlash             = true,     -- Briefly highlight snapped grid line(s)
		-- Minimap Button & Addon Compartment
		showCompartmentButton = true,
		showMinimapButton     = false,
		lockMinimapButton     = false,
		minimapAngle          = ns.DEFAULT_MINIMAP_ANGLE,
	}
end
