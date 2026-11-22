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

ns.DEFAULT_MINIMAP_ANGLE = 220

-- Default settings
function ns.BuildDefaultGeneral()
	return {
		-- Grid Appearance
		gridSize          = 8,        -- 8..256 px spacing between grid lines
		lineThickness     = 1,        -- 1..4 px physical pixel line thickness
		gridAlpha         = 0.10,     -- 0.10..1.00 opacity
		strata            = "HIGH",   -- Frame strata
		gridColor         = { r = 1.0, g = 1.0, b = 1.0 },
		centerColor       = { r = 1.0, g = 0.15, b = 0.15 },
		-- Behavior
		keepInCombat          = false,    -- Auto-hide grid in combat when false
		rememberState         = false,    -- Restore grid visibility across reloads
		snapToGrid            = false,    -- Snap non-protected addon frames to grid on drop
		-- Minimap Button & Addon Compartment
		showCompartmentButton = true,
		showMinimapButton     = false,
		lockMinimapButton     = false,
		minimapAngle          = ns.DEFAULT_MINIMAP_ANGLE,
	}
end
