-- PureGrid: Native Blizzard Settings UI (Options -> AddOns -> PureGrid).
local _, ns = ...

local mainCategory
local generalCanvas
local refreshCallbacks = {}

local function RefreshUI()
	for _, fn in ipairs(refreshCallbacks) do
		fn()
	end
end
ns.RefreshUI = RefreshUI

-- Native tooltip helper
local function AttachTooltip(widget, title, text)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 0.82, 0)
		if text then
			GameTooltip:AddLine(text, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Native Blizzard-styled button (clips text strictly inside button bounds)
local function MakeButton(parent, text, width, height, onClick)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 100, height or 22)
	btn:SetText(text)
	local fs = btn:GetFontString()
	if fs then
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
		fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
		fs:SetJustifyH("CENTER")
		fs:SetWordWrap(false)
	end
	if onClick then
		btn:SetScript("OnClick", onClick)
	end
	return btn
end

-- Confirmation dialog for "Reset to Defaults"
StaticPopupDialogs["PUREGRID_CONFIRM_RESET"] = {
	text = "Reset all PureGrid settings back to Default values?",
	button1 = "Reset",
	button2 = "Cancel",
	OnAccept = function()
		if ns.ResetDefaults then
			ns.ResetDefaults()
			RefreshUI()
			if ns.ForceRefresh then ns.ForceRefresh() end
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Native Blizzard-styled checkbox
local function MakeCheckbox(parent, label, tip, getFn, setFn)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	if label and label ~= "" then
		local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		fs:SetText(label)
		cb.label = fs
	end
	cb:SetScript("OnClick", function(self)
		local checked = self:GetChecked() and true or false
		setFn(checked)
		if ns.ForceRefresh then ns.ForceRefresh() end
		RefreshUI()
	end)
	if tip then
		AttachTooltip(cb, label or "Option", tip)
	end
	cb.Refresh = function(self)
		self:SetChecked(getFn() and true or false)
	end
	return cb
end

-- Clean native-look horizontal slider
local function MakeSlider(parent, label, minVal, maxVal, step, formatFn, tip, getFn, setFn)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(560, 26)

	local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nameFS:SetPoint("LEFT", row, "LEFT", 0, 0)
	nameFS:SetWidth(220)
	nameFS:SetJustifyH("LEFT")
	nameFS:SetText(label)

	local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(210, 16)
	slider:SetPoint("LEFT", nameFS, "RIGHT", 12, 0)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:SetBackdrop({
		bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
		edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8,
		insets = { left = 3, right = 3, top = 6, bottom = 6 },
	})
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

	local valFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	valFS:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	valFS:SetWidth(90)
	valFS:SetJustifyH("LEFT")

	local updating = false
	slider:SetScript("OnValueChanged", function(_, value)
		if updating then return end
		local snapped = math.floor((value / step) + 0.5) * step
		if snapped < minVal then snapped = minVal end
		if snapped > maxVal then snapped = maxVal end
		valFS:SetText(formatFn(snapped))
		setFn(snapped)
		if ns.ForceRefresh then ns.ForceRefresh() end
	end)

	if tip then
		AttachTooltip(slider, label, tip)
	end

	row.Refresh = function()
		updating = true
		local v = getFn()
		if v == nil then v = minVal end
		slider:SetValue(v)
		valFS:SetText(formatFn(v))
		updating = false
	end

	return row
end

-- Native Color Picker swatch row
local function MakeColorSwatch(parent, label, tip, getColorFn, setColorFn)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(560, 26)

	local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nameFS:SetPoint("LEFT", row, "LEFT", 0, 0)
	nameFS:SetWidth(220)
	nameFS:SetJustifyH("LEFT")
	nameFS:SetText(label)

	local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
	btn:SetSize(24, 20)
	btn:SetPoint("LEFT", nameFS, "RIGHT", 12, 0)
	btn:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false, edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

	local swatch = btn:CreateTexture(nil, "ARTWORK")
	swatch:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
	swatch:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)

	local hexFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hexFS:SetPoint("LEFT", btn, "RIGHT", 10, 0)
	hexFS:SetTextColor(0.75, 0.75, 0.75)

	local function UpdateDisplay(c)
		local r = (c and c.r) or 1
		local g = (c and c.g) or 1
		local b = (c and c.b) or 1
		swatch:SetColorTexture(r, g, b, 1)
		hexFS:SetText(string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
	end

	btn:SetScript("OnClick", function()
		local cur = getColorFn() or { r = 1, g = 1, b = 1 }
		local prevR, prevG, prevB = cur.r or 1, cur.g or 1, cur.b or 1

		if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow({
				r = prevR,
				g = prevG,
				b = prevB,
				hasOpacity = false,
				swatchFunc = function()
					local r, g, b = ColorPickerFrame:GetColorRGB()
					setColorFn(r, g, b)
					UpdateDisplay({ r = r, g = g, b = b })
					if ns.ForceRefresh then ns.ForceRefresh() end
				end,
				cancelFunc = function()
					setColorFn(prevR, prevG, prevB)
					UpdateDisplay({ r = prevR, g = prevG, b = prevB })
					if ns.ForceRefresh then ns.ForceRefresh() end
				end,
			})
		end
	end)

	if tip then
		AttachTooltip(btn, label, tip)
	end

	row.Refresh = function()
		UpdateDisplay(getColorFn())
	end

	return row
end

-- Context menu helper using WoW Forever's native MenuUtil
local function OpenDropdownMenu(owner, buildFn)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
			buildFn(rootDescription)
		end)
	end
end

local function MakeDropdownRow(parent, label, options, labelByVal, tip, getFn, setFn)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(560, 26)
	local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
	lbl:SetWidth(220)
	lbl:SetJustifyH("LEFT")
	lbl:SetText(label)

	local btn = MakeButton(row, "", 210, 22)
	btn:SetPoint("LEFT", lbl, "RIGHT", 12, 0)
	if tip then
		AttachTooltip(btn, label, tip)
	end
	btn:SetScript("OnClick", function(self)
		OpenDropdownMenu(self, function(root)
			for _, opt in ipairs(options) do
				root:CreateRadio(opt.label,
					function() return getFn() == opt.value end,
					function()
						setFn(opt.value)
						RefreshUI()
						if ns.ForceRefresh then ns.ForceRefresh() end
					end
				)
			end
		end)
	end)
	row.Refresh = function()
		local val = getFn()
		btn:SetText(labelByVal[val] or tostring(val))
	end
	return row
end

local function MakeSectionHeader(parent, text, yOffset)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
	fs:SetText(text)
	return fs
end

--------------------------------------------------------------------------------
-- MAIN SETTINGS PAGE (PureGrid)
--------------------------------------------------------------------------------
local function BuildGeneralPage()
	local canvas = CreateFrame("Frame")
	canvas:Hide()

	local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
	title:SetText("PureGrid")

	local resetBtn = MakeButton(canvas, "Reset to Defaults", 130, 22, function()
		StaticPopup_Show("PUREGRID_CONFIRM_RESET")
	end)
	resetBtn:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -24, -14)
	AttachTooltip(resetBtn, "Reset to Defaults", "Resets all PureGrid settings back to their default values.")

	local sub = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetPoint("RIGHT", resetBtn, "LEFT", -12, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText("Lightweight, toggleable screen alignment grid for WoW Forever. Configure spacing, guides, quick-bar, Edit Mode sync, and snap-on-drop.")
	sub:SetTextColor(0.75, 0.75, 0.75)

	local divider = canvas:CreateTexture(nil, "ARTWORK")
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8)
	divider:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -24, -52)
	divider:SetColorTexture(0.35, 0.35, 0.35, 0.6)

	local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -32, 12)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(600, 1)
	scroll:SetScrollChild(content)

	canvas.content = content
	canvas.scroll = scroll

	local widgets = {}
	local y = -6

	local function Add(widget, height)
		widget:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
		y = y - (height or 28)
		widgets[#widgets + 1] = widget
		return widget
	end

	-- Quick Action Row
	local actionRow = CreateFrame("Frame", nil, content)
	actionRow:SetSize(560, 28)

	local toggleBtn = MakeButton(actionRow, "Toggle Grid", 140, 24, function()
		if ns.ToggleGrid then
			ns.ToggleGrid()
		end
	end)
	toggleBtn:SetPoint("LEFT", actionRow, "LEFT", 0, 0)
	AttachTooltip(toggleBtn, "Toggle Grid", "Show or hide the alignment grid overlay immediately. You can also toggle via Addon Compartment, Minimap button, /puregrid toggle, or a Keybinding.")

	local statusFS = actionRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	statusFS:SetPoint("LEFT", toggleBtn, "RIGHT", 14, 0)

	actionRow.Refresh = function()
		local status = ns.GetGridStatusText and ns.GetGridStatusText() or "|cffff6666Hidden|r"
		statusFS:SetText("Current Status: " .. status)
		if ns.IsGridDesired and ns.IsGridDesired() then
			toggleBtn:SetText("Hide Grid")
		else
			toggleBtn:SetText("Show Grid")
		end
	end
	Add(actionRow, 36)

	-- Section: Grid Layout
	MakeSectionHeader(content, "Grid Layout", y)
	y = y - 22

	Add(MakeSlider(content, "Grid Spacing (Pixel Size)", 8, 256, 2,
		function(v) return v .. " px" end,
		"Distance in physical pixels between repeating grid lines, radiating symmetrically from the center of the screen.",
		function() return ns.GetDB().gridSize end,
		function(v) ns.GetDB().gridSize = v end
	), 26)

	-- Quick spacing preset pills
	local presetRow = CreateFrame("Frame", nil, content)
	presetRow:SetSize(560, 24)
	local presetLbl = presetRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	presetLbl:SetPoint("LEFT", presetRow, "LEFT", 0, 0)
	presetLbl:SetWidth(220)
	presetLbl:SetJustifyH("LEFT")
	presetLbl:SetTextColor(0.75, 0.75, 0.75)
	presetLbl:SetText("Quick Presets")

	local pxX = 232
	for _, val in ipairs(ns.SPACING_PRESETS) do
		local pBtn = MakeButton(presetRow, val .. " px", 62, 20, function()
			ns.GetDB().gridSize = val
			if ns.ForceRefresh then ns.ForceRefresh() end
			RefreshUI()
		end)
		pBtn:SetPoint("LEFT", presetRow, "LEFT", pxX, 0)
		AttachTooltip(pBtn, "Spacing Preset: " .. val .. " px", "Set grid spacing directly to " .. val .. " px (or type /puregrid " .. val .. ").")
		pxX = pxX + 66
	end
	Add(presetRow, 28)

	Add(MakeSlider(content, "Line Thickness", 1, 4, 1,
		function(v) return v .. " px" end,
		"Thickness of the repeating grid lines in physical screen pixels.",
		function() return ns.GetDB().lineThickness end,
		function(v) ns.GetDB().lineThickness = v end
	), 28)

	Add(MakeSlider(content, "Grid Opacity", 0.10, 1.00, 0.05,
		function(v) return math.floor(v * 100 + 0.5) .. "%" end,
		"Transparency of the repeating grid lines.",
		function() return ns.GetDB().gridAlpha end,
		function(v) ns.GetDB().gridAlpha = v end
	), 28)

	Add(MakeCheckbox(content, "Highlight Every Nth Line (Major Lines)",
		"Accents every Nth grid line with higher opacity like graph paper so measuring symmetrical distances from center is easier.",
		function() return ns.GetDB().majorLineEnabled ~= false end,
		function(v) ns.GetDB().majorLineEnabled = v end
	), 26)

	Add(MakeSlider(content, "Major Line Interval", 2, 16, 1,
		function(v) return "Every " .. v .. "th" end,
		"Which grid lines are accented when Major Lines are enabled (default: every 5th line).",
		function() return ns.GetDB().majorLineInterval or 5 end,
		function(v) ns.GetDB().majorLineInterval = v end
	), 28)

	Add(MakeCheckbox(content, "Center Crosshair-Only Mode",
		"Hides the repeating grid lines and displays only the center crosshairs (plus any active reference or custom guides).",
		function() return ns.GetDB().crosshairOnly and true or false end,
		function(v) ns.GetDB().crosshairOnly = v end
	), 28)

	Add(MakeDropdownRow(content, "Grid Layer (Strata)", ns.STRATA_OPTIONS, ns.STRATA_LABEL_BY_VALUE,
		"Controls whether the grid renders behind UI frames (Background) or on top of opaque UI frames (High / Dialog).",
		function() return ns.GetDB().strata or "HIGH" end,
		function(v) ns.GetDB().strata = v end
	), 32)

	-- Section: Center & Major Lines / Colors
	y = y - 6
	MakeSectionHeader(content, "Center & Major Lines / Colors", y)
	y = y - 22

	Add(MakeSlider(content, "Center & Major Thickness", 1, 4, 1,
		function(v) return v .. " px" end,
		"Thickness in physical screen pixels for both the center crosshairs and highlighted major (every Nth) grid lines.",
		function() return ns.GetDB().centerThickness or 1 end,
		function(v) ns.GetDB().centerThickness = v end
	), 28)

	Add(MakeSlider(content, "Center & Major Opacity", 0.10, 1.00, 0.05,
		function(v) return math.floor(v * 100 + 0.5) .. "%" end,
		"Opacity for both the center crosshairs and highlighted major (every Nth) grid lines so they stand out cleanly above the minor grid.",
		function() return ns.GetDB().centerAlpha or 0.50 end,
		function(v) ns.GetDB().centerAlpha = v end
	), 28)

	Add(MakeColorSwatch(content, "Grid Line Color",
		"Color of the repeating grid lines.",
		function() return ns.GetDB().gridColor end,
		function(r, g, b) ns.GetDB().gridColor = { r = r, g = g, b = b } end
	), 26)

	Add(MakeColorSwatch(content, "Center Line Color",
		"Color of the vertical and horizontal center lines (red by default).",
		function() return ns.GetDB().centerColor end,
		function(r, g, b) ns.GetDB().centerColor = { r = r, g = g, b = b } end
	), 26)

	Add(MakeColorSwatch(content, "Custom Guide Color",
		"Color of custom mirrored vertical and horizontal guide lines.",
		function() return ns.GetDB().guideColor end,
		function(r, g, b) ns.GetDB().guideColor = { r = r, g = g, b = b } end
	), 32)

	-- Section: Guides & Reference Lines
	y = y - 6
	MakeSectionHeader(content, "Guides & Reference Lines", y)
	y = y - 22

	Add(MakeDropdownRow(content, "Screen Reference Guides", ns.REFERENCE_GUIDE_OPTIONS, ns.REFERENCE_GUIDE_LABEL_BY_VALUE,
		"Optional subtle gold reference lines at Rule of Thirds (33% / 66%) or Quarters (25% / 75%) of the screen.",
		function() return ns.GetDB().referenceGuide or "none" end,
		function(v) ns.GetDB().referenceGuide = v end
	), 30)

	local guideToolRow = CreateFrame("Frame", nil, content)
	guideToolRow:SetSize(560, 26)

	local addVBtn = MakeButton(guideToolRow, "+ Vertical Guide", 122, 22, function()
		if ns.AddCustomGuide then
			ns.AddCustomGuide("V", 200, true)
			if ns.SetGuideEditMode then ns.SetGuideEditMode(true) end
		end
	end)
	addVBtn:SetPoint("LEFT", guideToolRow, "LEFT", 0, 0)
	AttachTooltip(addVBtn, "Add Vertical Guide", "Adds a mirrored vertical guide (±200 px from center) and unlocks draggable handles on screen.")

	local addHBtn = MakeButton(guideToolRow, "+ Horizontal Guide", 132, 22, function()
		if ns.AddCustomGuide then
			ns.AddCustomGuide("H", -160, false)
			if ns.SetGuideEditMode then ns.SetGuideEditMode(true) end
		end
	end)
	addHBtn:SetPoint("LEFT", addVBtn, "RIGHT", 6, 0)
	AttachTooltip(addHBtn, "Add Horizontal Guide", "Adds a horizontal guide (-160 px from center) and unlocks draggable handles on screen.")

	local editGuidesBtn = MakeButton(guideToolRow, "Edit Guides", 96, 22, function()
		if ns.SetGuideEditMode and ns.IsGuideEditMode then
			ns.SetGuideEditMode(not ns.IsGuideEditMode())
		end
	end)
	editGuidesBtn:SetPoint("LEFT", addHBtn, "RIGHT", 6, 0)
	AttachTooltip(editGuidesBtn, "Edit Guides on Screen", "Unlock draggable guide handles on screen (Left-Drag to move, Shift for 1px, Alt/Middle-Click to toggle Mirror ±, Right-Click to delete).")

	local clearGuidesBtn = MakeButton(guideToolRow, "Clear All", 80, 22, function()
		if ns.ClearCustomGuides then ns.ClearCustomGuides() end
	end)
	clearGuidesBtn:SetPoint("LEFT", editGuidesBtn, "RIGHT", 6, 0)
	AttachTooltip(clearGuidesBtn, "Clear All Custom Guides", "Removes all custom guide lines.")

	guideToolRow.Refresh = function()
		local editing = ns.IsGuideEditMode and ns.IsGuideEditMode()
		editGuidesBtn:SetText(editing and "Lock Guides" or "Edit Guides")
	end
	Add(guideToolRow, 28)

	local guideInfoRow = CreateFrame("Frame", nil, content)
	guideInfoRow:SetSize(560, 20)
	local guideInfoFS = guideInfoRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	guideInfoFS:SetPoint("LEFT", guideInfoRow, "LEFT", 2, 0)
	guideInfoFS:SetTextColor(0.75, 0.75, 0.75)
	guideInfoRow.Refresh = function()
		local guides = ns.GetDB() and ns.GetDB().guides
		local count = type(guides) == "table" and #guides or 0
		if count == 0 then
			guideInfoFS:SetText("Active Custom Guides: None (up to " .. ns.MAX_CUSTOM_GUIDES .. " guides; drag handles on screen to position & mirror).")
		else
			local parts = {}
			for _, g in ipairs(guides) do
				local sym = g.mirror and "±" or (g.offset >= 0 and "+" or "")
				local val = g.mirror and math.abs(g.offset) or g.offset
				parts[#parts + 1] = string.format("%s:%s%d", g.axis, sym, val)
			end
			guideInfoFS:SetText("Active Custom Guides (" .. count .. "/" .. ns.MAX_CUSTOM_GUIDES .. "): " .. table.concat(parts, ", "))
		end
	end
	Add(guideInfoRow, 28)

	-- Section: Quick-Bar & Cursor HUD
	y = y - 6
	MakeSectionHeader(content, "Quick-Bar & Cursor HUD", y)
	y = y - 22

	Add(MakeCheckbox(content, "Show Floating Quick-Bar While Grid is Visible",
		"Displays a compact, draggable toolbar while the grid is shown so you can adjust spacing, opacity, crosshair mode, snap, and guides without opening Settings.",
		function() return ns.GetDB().showQuickBar ~= false end,
		function(v)
			ns.GetDB().showQuickBar = v
			if ns.UpdateQuickBar then ns.UpdateQuickBar() end
		end
	), 26)

	Add(MakeCheckbox(content, "Show Cursor Center Offset (X / Y)",
		"Displays a compact readout showing your cursor's live physical pixel offset from exact screen center (0, 0) while the grid is shown.",
		function() return ns.GetDB().showCursorCoords and true or false end,
		function(v)
			ns.GetDB().showCursorCoords = v
			if ns.UpdateQuickBar then ns.UpdateQuickBar() end
		end
	), 28)

	local resetQBRow = CreateFrame("Frame", nil, content)
	resetQBRow:SetSize(560, 26)
	local resetQBBtn = MakeButton(resetQBRow, "Reset Quick-Bar Position", 175, 22, function()
		if ns.ResetQuickBarPosition then ns.ResetQuickBarPosition() end
	end)
	resetQBBtn:SetPoint("LEFT", resetQBRow, "LEFT", 0, 0)
	AttachTooltip(resetQBBtn, "Reset Quick-Bar Position", "Returns the Floating Quick-Bar to the top-center of the screen.")
	Add(resetQBRow, 32)

	-- Section: Behavior & Edit Mode
	y = y - 6
	MakeSectionHeader(content, "Behavior & Edit Mode", y)
	y = y - 22

	Add(MakeCheckbox(content, "Keep Grid Visible in Combat",
		"When disabled (default), the grid automatically hides when entering combat and returns after combat ends.",
		function() return ns.GetDB().keepInCombat and true or false end,
		function(v) ns.GetDB().keepInCombat = v end
	), 26)

	Add(MakeCheckbox(content, "Remember Grid State Across Reloads",
		"When enabled, if the grid was shown before logging out or reloading, it will automatically show again on login.",
		function() return ns.GetDB().rememberState and true or false end,
		function(v) ns.GetDB().rememberState = v end
	), 26)

	Add(MakeCheckbox(content, "Auto-Show Grid in Blizzard Edit Mode",
		"Automatically displays PureGrid whenever you open Blizzard's Edit Mode and hides it when you exit.",
		function() return ns.GetDB().autoShowInEditMode and true or false end,
		function(v) ns.GetDB().autoShowInEditMode = v end
	), 26)

	Add(MakeCheckbox(content, "Hide Blizzard's Edit Mode Grid While PureGrid is Active",
		"Cleanly hides Blizzard's coarse Edit Mode grid (via SetAlpha(0), zero taint) while PureGrid is visible in Edit Mode so you never see two grids stacked.",
		function() return ns.GetDB().hideBlizzardEditGrid ~= false end,
		function(v) ns.GetDB().hideBlizzardEditGrid = v end
	), 28)

	Add(MakeCheckbox(content, "Snap Addon Frames to Grid on Drop",
		"When the grid is visible out of combat, snaps non-protected movable addon frames to the closest grid line when released. Hold Shift while dropping to place freely. Blizzard Edit Mode frames are skipped to avoid combat taint.",
		function() return ns.GetDB().snapToGrid and true or false end,
		function(v) ns.GetDB().snapToGrid = v end
	), 28)

	Add(MakeDropdownRow(content, "Snap Mode", ns.SNAP_MODE_OPTIONS, ns.SNAP_MODE_LABEL_BY_VALUE,
		"Choose whether snapped addon frames align by their nearest edge or center, center only, or edges only.",
		function() return ns.GetDB().snapMode or "edges" end,
		function(v) ns.GetDB().snapMode = v end
	), 28)

	Add(MakeCheckbox(content, "Flash Snapped Grid Line",
		"Briefly highlights the exact grid line(s) an addon frame just snapped to.",
		function() return ns.GetDB().snapFlash ~= false end,
		function(v) ns.GetDB().snapFlash = v end
	), 32)

	-- Section: Minimap Button & Addon Compartment
	y = y - 6
	MakeSectionHeader(content, "Minimap Button & Addon Compartment", y)
	y = y - 22

	Add(MakeCheckbox(content, "Show Addon Compartment Button",
		"Show PureGrid in the Blizzard Addon Compartment dropdown (Left-Click: Toggle Grid, Right-Click: Settings).",
		function() return ns.GetDB().showCompartmentButton ~= false end,
		function(v)
			ns.GetDB().showCompartmentButton = v
			if ns.UpdateCompartmentButton then ns.UpdateCompartmentButton() end
		end
	), 26)

	Add(MakeCheckbox(content, "Show Minimap Button",
		"Display a dedicated PureGrid toggle button on the Minimap border (disabled by default).",
		function() return ns.GetDB().showMinimapButton and true or false end,
		function(v)
			ns.GetDB().showMinimapButton = v
			if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
		end
	), 26)

	Add(MakeCheckbox(content, "Lock Minimap Button",
		"Prevent dragging the Minimap button around the Minimap border.",
		function() return ns.GetDB().lockMinimapButton and true or false end,
		function(v) ns.GetDB().lockMinimapButton = v end
	), 30)

	local resetPosRow = CreateFrame("Frame", nil, content)
	resetPosRow:SetSize(560, 28)
	local resetPosBtn = MakeButton(resetPosRow, "Reset Minimap Position", 170, 22, function()
		if ns.ResetMinimapButtonPosition then
			ns.ResetMinimapButtonPosition()
		end
	end)
	resetPosBtn:SetPoint("LEFT", resetPosRow, "LEFT", 0, 0)
	AttachTooltip(resetPosBtn, "Reset Minimap Position", "Returns the Minimap button to its default position around the Minimap rim.")
	Add(resetPosRow, 36)

	content:SetHeight(math.abs(y) + 24)

	local function RefreshGeneral()
		if not ns.GetDB() then return end
		for _, w in ipairs(widgets) do
			if w.Refresh then
				w:Refresh()
			end
		end
	end

	canvas:SetScript("OnShow", RefreshGeneral)
	refreshCallbacks[#refreshCallbacks + 1] = RefreshGeneral
	return canvas
end

--------------------------------------------------------------------------------
-- REGISTER IN BLIZZARD OPTIONS -> ADDONS
--------------------------------------------------------------------------------
function ns.InitUI()
	generalCanvas = BuildGeneralPage()

	if Settings and Settings.RegisterCanvasLayoutCategory then
		mainCategory = Settings.RegisterCanvasLayoutCategory(generalCanvas, "PureGrid")
		Settings.RegisterAddOnCategory(mainCategory)
	end
end

function ns.OpenSettings()
	if InCombatLockdown and InCombatLockdown() then
		print("|cff66ccffPureGrid:|r Cannot open Blizzard Settings during combat. Try again after combat.")
		return
	end
	if mainCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(mainCategory:GetID())
	end
end

function ns.ToggleSettings()
	if InCombatLockdown and InCombatLockdown() then
		print("|cff66ccffPureGrid:|r Cannot toggle Blizzard Settings during combat. Try again after combat.")
		return
	end
	if SettingsPanel and SettingsPanel:IsShown() then
		if HideUIPanel then
			HideUIPanel(SettingsPanel)
		else
			SettingsPanel:Hide()
		end
	else
		ns.OpenSettings()
	end
end
