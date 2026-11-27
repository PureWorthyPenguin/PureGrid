-- PureGrid: Addon entry point, SavedVariables, Addon Compartment, and /puregrid slash command.
local ADDON_NAME, ns = ...

-- Fill any missing default keys in PureGridDB without overwriting user customizations
local function MergeDefaults(db)
	local def = ns.BuildDefaultGeneral()
	for k, v in pairs(def) do
		if db[k] == nil then
			db[k] = ns.DeepCopy(v)
		elseif type(v) == "table" and type(db[k]) ~= "table" then
			db[k] = ns.DeepCopy(v)
		elseif type(v) == "table" and type(db[k]) == "table" and k ~= "guides" then
			for subK, subV in pairs(v) do
				if db[k][subK] == nil then
					db[k][subK] = subV
				end
			end
		end
	end
end

local function InitSavedVariables()
	if type(PureGridDB) ~= "table" then
		PureGridDB = {}
	end
	-- Clean up any legacy profile tables if upgrading from an early build
	PureGridDB.profiles = nil
	PureGridDB.profileKeys = nil

	MergeDefaults(PureGridDB)
end

function ns.GetDB()
	return PureGridDB
end

function ns.ResetDefaults()
	local lastShown = PureGridDB and PureGridDB.lastGridShown or false
	PureGridDB = ns.BuildDefaultGeneral()
	PureGridDB.lastGridShown = lastShown
	if ns.SetGuideEditMode then ns.SetGuideEditMode(false) end
	if ns.ResetQuickBarPosition then ns.ResetQuickBarPosition() end
	print("|cff66ccffPureGrid:|r All settings reset to defaults.")
end

-- Global keybinding callback (used by Bindings.xml)
function PureGrid_ToggleGrid()
	if ns.ToggleGrid then
		ns.ToggleGrid()
	end
end

-- Addon Compartment dynamic registration (Left-Click: Toggle Grid, Right-Click: Settings)
local compartmentData = {
	text = "PureGrid",
	icon = "Interface\\Icons\\INV_Misc_Net_01",
	registerForAnyClick = true,
	notCheckable = true,
	func = function(_, menuInputData)
		local buttonName = type(menuInputData) == "table" and menuInputData.buttonName or menuInputData
		if buttonName == "RightButton" then
			if ns.OpenSettings then
				ns.OpenSettings()
			end
		else
			if ns.ToggleGrid then
				ns.ToggleGrid()
			end
		end
	end,
	funcOnEnter = function(menuButtonFrame)
		GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
		GameTooltip:SetText("PureGrid", 1, 0.82, 0)
		local status = ns.GetGridStatusText and ns.GetGridStatusText() or "|cffff6666Hidden|r"
		GameTooltip:AddLine("Grid: " .. status, 1, 1, 1)
		GameTooltip:AddLine("Left-Click: Toggle Grid", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-Click: Open Settings", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end,
	funcOnLeave = function()
		GameTooltip:Hide()
	end,
}

local compartmentRegistered = false

local function RemoveFromCompartment()
	if not AddonCompartmentFrame then
		return false
	end
	if AddonCompartmentFrame.UnregisterAddon then
		AddonCompartmentFrame:UnregisterAddon(compartmentData)
		if AddonCompartmentFrame.UpdateDisplay then
			AddonCompartmentFrame:UpdateDisplay()
		end
		return true
	end
	-- Locate the internal list holding our exact compartmentData table reference
	local removed = false
	for _, field in pairs(AddonCompartmentFrame) do
		if type(field) == "table" then
			for i = #field, 1, -1 do
				if field[i] == compartmentData then
					table.remove(field, i)
					removed = true
				end
			end
		end
	end
	if removed and AddonCompartmentFrame.UpdateDisplay then
		AddonCompartmentFrame:UpdateDisplay()
	end
	return removed
end

function ns.UpdateCompartmentButton()
	if not AddonCompartmentFrame then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local shouldShow = not db or db.showCompartmentButton ~= false

	if shouldShow then
		if not compartmentRegistered and AddonCompartmentFrame.RegisterAddon then
			AddonCompartmentFrame:RegisterAddon(compartmentData)
			compartmentRegistered = true
		end
	else
		if compartmentRegistered then
			if RemoveFromCompartment() then
				compartmentRegistered = false
			else
				print("|cff66ccffPureGrid:|r Type |cffffff00/reload|r to remove the Addon Compartment button.")
			end
		end
	end
end

-- Slash command: /puregrid
SLASH_PUREGRID1 = "/puregrid"
SlashCmdList["PUREGRID"] = function(msg)
	local raw = strtrim((msg or ""):lower())
	local cmd, arg = raw:match("^(%S+)%s*(.*)$")
	cmd = cmd or ""

	local numericSpacing = tonumber(raw)
	if numericSpacing then
		local clamped = math.max(8, math.min(256, math.floor((numericSpacing / 2) + 0.5) * 2))
		PureGridDB.gridSize = clamped
		if ns.ForceRefresh then ns.ForceRefresh() end
		if ns.RefreshUI then ns.RefreshUI() end
		print("|cff66ccffPureGrid:|r Grid spacing set to |cffffff00" .. clamped .. " px|r.")
		return
	end

	if cmd == "toggle" then
		if ns.ToggleGrid then ns.ToggleGrid() end
	elseif cmd == "on" or cmd == "show" then
		if ns.SetGridShown then ns.SetGridShown(true) end
	elseif cmd == "off" or cmd == "hide" then
		if ns.SetGridShown then ns.SetGridShown(false) end
	elseif cmd == "alpha" or cmd == "opacity" then
		local pct = tonumber(arg)
		if pct then
			local clamped = math.max(10, math.min(100, math.floor((pct / 5) + 0.5) * 5))
			PureGridDB.gridAlpha = clamped / 100
			if ns.ForceRefresh then ns.ForceRefresh() end
			if ns.RefreshUI then ns.RefreshUI() end
			print("|cff66ccffPureGrid:|r Grid opacity set to |cffffff00" .. clamped .. "%|r.")
		else
			print("|cff66ccffPureGrid:|r Usage: |cffffff00/puregrid alpha 10-100|r (e.g. /puregrid alpha 25)")
		end
	elseif cmd == "crosshair" or cmd == "cross" then
		PureGridDB.crosshairOnly = not PureGridDB.crosshairOnly
		if ns.ForceRefresh then ns.ForceRefresh() end
		if ns.RefreshUI then ns.RefreshUI() end
		print("|cff66ccffPureGrid:|r Center Crosshair-Only mode " .. (PureGridDB.crosshairOnly and "|cff66ff66ON|r." or "|cffff6666OFF|r."))
	elseif cmd == "snap" then
		PureGridDB.snapToGrid = not PureGridDB.snapToGrid
		if ns.UpdateQuickBar then ns.UpdateQuickBar() end
		if ns.RefreshUI then ns.RefreshUI() end
		print("|cff66ccffPureGrid:|r Snap-on-Drop " .. (PureGridDB.snapToGrid and "|cff66ff66ON|r." or "|cffff6666OFF|r."))
	elseif cmd == "guides" or cmd == "guide" then
		if ns.SetGuideEditMode and ns.IsGuideEditMode then
			local nextState = not ns.IsGuideEditMode()
			ns.SetGuideEditMode(nextState)
			print("|cff66ccffPureGrid:|r Custom Guide Edit Mode " .. (nextState and "|cff66ff66UNLOCKED|r." or "|cffff6666LOCKED|r."))
		end
	elseif cmd == "reset" then
		if ns.ResetMinimapButtonPosition then ns.ResetMinimapButtonPosition() end
		if ns.ResetQuickBarPosition then ns.ResetQuickBarPosition() end
	elseif cmd == "help" then
		print("|cff66ccffPureGrid Commands:|r")
		print("  |cffffff00/puregrid|r - Open Settings")
		print("  |cffffff00/puregrid toggle|r | |cffffff00on|r | |cffffff00off|r - Toggle, show, or hide grid")
		print("  |cffffff00/puregrid <8-256>|r - Set grid spacing (e.g. /puregrid 32)")
		print("  |cffffff00/puregrid alpha <10-100>|r - Set grid opacity (e.g. /puregrid alpha 25)")
		print("  |cffffff00/puregrid crosshair|r - Toggle Center Crosshair-Only mode")
		print("  |cffffff00/puregrid snap|r - Toggle Snap-on-Drop for addon frames")
		print("  |cffffff00/puregrid guides|r - Lock/unlock custom guide drag handles")
		print("  |cffffff00/puregrid reset|r - Reset Minimap button & Quick-Bar positions")
	else
		if ns.OpenSettings then ns.OpenSettings() end
	end
end

-- Lifecycle events
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			InitSavedVariables()
			ns.InitUI()
		elseif arg1 == "Blizzard_EditMode" then
			if ns.TryHookEditMode then ns.TryHookEditMode() end
		end
	elseif event == "PLAYER_LOGIN" then
		local function SafeCall(label, fn)
			if type(fn) ~= "function" then return end
			local ok, err = pcall(fn)
			if not ok then
				print("|cff66ccffPureGrid:|r |cffff6666Error in " .. label .. ":|r " .. tostring(err))
			end
		end
		SafeCall("InitGrid", ns.InitGrid)
		SafeCall("InitQuickBar", ns.InitQuickBar)
		SafeCall("InitMinimapButton", ns.InitMinimapButton)
		SafeCall("UpdateCompartmentButton", ns.UpdateCompartmentButton)
	end
end)
