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
		elseif type(v) == "table" and type(db[k]) == "table" then
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
	local cmd = strtrim((msg or ""):lower())
	if cmd == "toggle" then
		if ns.ToggleGrid then ns.ToggleGrid() end
	elseif cmd == "on" or cmd == "show" then
		if ns.SetGridShown then ns.SetGridShown(true) end
	elseif cmd == "off" or cmd == "hide" then
		if ns.SetGridShown then ns.SetGridShown(false) end
	elseif cmd == "reset" then
		if ns.ResetMinimapButtonPosition then ns.ResetMinimapButtonPosition() end
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
		end
	elseif event == "PLAYER_LOGIN" then
		ns.InitGrid()
		ns.InitMinimapButton()
		ns.UpdateCompartmentButton()
	end
end)
