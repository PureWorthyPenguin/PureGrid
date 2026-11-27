-- PureGrid: Minimalist Floating Quick-Bar and Live Cursor Center-Offset Readout (zero idle overhead).
local _, ns = ...

local quickBar
local coordsFrame
local coordsText
local coordsElapsed = 0

local spacingValFS
local alphaValFS
local spMinusBtn
local spPlusBtn
local opMinusBtn
local opPlusBtn
local crossBtn
local snapBtn
local editGuidesBtn
local clearGuidesBtn

local function AttachQuickTip(widget, title, text)
	widget:SetScript("OnEnter", function(self)
		if self.hl and self._flatEnabled ~= false then
			self.hl:Show()
		end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(title, 1, 0.82, 0)
		if text then
			GameTooltip:AddLine(text, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function(self)
		if self.hl then
			self.hl:Hide()
		end
		GameTooltip:Hide()
	end)
end

local function RefreshFlatVisual(btn)
	if not btn or not btn.fs then return end
	if btn._flatEnabled == false then
		btn.bg:Hide()
		btn.hl:Hide()
		btn.fs:SetTextColor(0.36, 0.36, 0.38, 1)
	elseif btn._flatActive then
		btn.bg:SetColorTexture(0.18, 0.65, 0.35, 0.28)
		btn.bg:Show()
		btn.fs:SetTextColor(0.45, 1.0, 0.55, 1)
	else
		btn.bg:Hide()
		if btn._isAccent then
			btn.fs:SetTextColor(1.0, 0.82, 0.20, 1)
		elseif btn._isClose then
			btn.fs:SetTextColor(0.75, 0.75, 0.78, 1)
		else
			btn.fs:SetTextColor(0.86, 0.86, 0.88, 1)
		end
	end
end

local function MakeFlatBtn(parent, text, width, onClick, tipTitle, tipText, style)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 22, 18)
	btn._flatEnabled = true
	btn._flatActive = false
	btn._isClose = (style == "close")
	btn._isAccent = (style == "accent")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:Hide()
	btn.bg = bg

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	if btn._isClose then
		hl:SetColorTexture(0.85, 0.20, 0.20, 0.35)
	else
		hl:SetColorTexture(1.0, 0.82, 0.25, 0.18)
	end
	hl:Hide()
	btn.hl = hl

	local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
	fs:SetJustifyH("CENTER")
	fs:SetWordWrap(false)
	fs:SetText(text)
	btn.fs = fs

	btn.SetFlatEnabled = function(self, enabled)
		self._flatEnabled = enabled and true or false
		self:SetEnabled(self._flatEnabled)
		RefreshFlatVisual(self)
	end

	btn.SetFlatActive = function(self, active)
		self._flatActive = active and true or false
		RefreshFlatVisual(self)
	end

	if onClick then
		btn:SetScript("OnClick", function(self)
			if self._flatEnabled == false then return end
			onClick(self)
		end)
	end

	if tipTitle then
		AttachQuickTip(btn, tipTitle, tipText)
	else
		btn:SetScript("OnEnter", function(self)
			if self.hl and self._flatEnabled ~= false then self.hl:Show() end
		end)
		btn:SetScript("OnLeave", function(self)
			if self.hl then self.hl:Hide() end
		end)
	end

	RefreshFlatVisual(btn)
	return btn
end

local function MakeDivider(parent, xOffset)
	local div = parent:CreateTexture(nil, "ARTWORK")
	div:SetSize(1, 14)
	div:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
	div:SetColorTexture(0.55, 0.48, 0.30, 0.38)
	return div
end

local function StepSpacing(dir)
	local db = ns.GetDB and ns.GetDB()
	if not db then return end
	local cur = db.gridSize or 16
	if IsShiftKeyDown and IsShiftKeyDown() then
		db.gridSize = math.max(8, math.min(256, cur + (dir * 2)))
	else
		local steps = ns.QUICKBAR_SPACING_STEPS
		if dir > 0 then
			local nextVal = steps[#steps]
			for i = 1, #steps do
				if steps[i] > cur then
					nextVal = steps[i]
					break
				end
			end
			db.gridSize = nextVal
		else
			local prevVal = steps[1]
			for i = #steps, 1, -1 do
				if steps[i] < cur then
					prevVal = steps[i]
					break
				end
			end
			db.gridSize = prevVal
		end
	end
	if ns.ForceRefresh then ns.ForceRefresh() end
	if ns.RefreshUI then ns.RefreshUI() end
end

local function StepOpacity(dir)
	local db = ns.GetDB and ns.GetDB()
	if not db then return end
	local step = (IsShiftKeyDown and IsShiftKeyDown()) and 0.05 or 0.10
	local cur = db.gridAlpha or 0.10
	local nextVal = math.floor(((cur + dir * step) / 0.05) + 0.5) * 0.05
	db.gridAlpha = math.max(0.10, math.min(1.00, nextVal))
	if ns.ForceRefresh then ns.ForceRefresh() end
	if ns.RefreshUI then ns.RefreshUI() end
end

local function ApplyQuickBarPosition()
	if not quickBar then return end
	local db = ns.GetDB and ns.GetDB()
	local pos = db and db.quickBarPos
	quickBar:ClearAllPoints()
	if type(pos) == "table" and pos.point and pos.relPoint and pos.x and pos.y then
		quickBar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		quickBar:SetPoint("TOP", UIParent, "TOP", 0, -14)
	end
end

local function PositionCoordsFrame()
	if not coordsFrame then return end
	coordsFrame:ClearAllPoints()
	if quickBar and quickBar:IsShown() then
		coordsFrame:SetPoint("TOP", quickBar, "BOTTOM", 0, -4)
	else
		coordsFrame:SetPoint("TOP", UIParent, "TOP", 0, -14)
	end
end

local function CoordsOnUpdate(_, elapsed)
	coordsElapsed = coordsElapsed + (elapsed or 0)
	if coordsElapsed < 0.05 then return end
	coordsElapsed = 0

	local physW, physH = GetPhysicalScreenSize()
	physW = ns.SafeNumber(physW)
	physH = ns.SafeNumber(physH)
	local cx, cy = GetCursorPosition()
	cx = ns.SafeNumber(cx)
	cy = ns.SafeNumber(cy)
	if not physW or not physH or physW <= 0 or physH <= 0 or not cx or not cy then
		return
	end

	-- GetCursorPosition() returns 768-height virtual coords; convert to physical pixels
	local toPhys = physH / 768
	local dx = math.floor((cx * toPhys) - (physW * 0.5) + 0.5)
	local dy = math.floor((cy * toPhys) - (physH * 0.5) + 0.5)
	local sx = dx >= 0 and ("+" .. dx) or tostring(dx)
	local sy = dy >= 0 and ("+" .. dy) or tostring(dy)
	coordsText:SetText(string.format("|cffffd100X:|r %s   |cffffd100Y:|r %s", sx, sy))
end

function ns.InitQuickBar()
	if quickBar then return end

	local bar = CreateFrame("Frame", "PureGridQuickBar", UIParent, "BackdropTemplate")
	bar:SetSize(430, 26)
	bar:SetFrameStrata("DIALOG")
	bar:SetFrameLevel(20)
	bar:SetClampedToScreen(true)
	bar:EnableMouse(true)
	bar:SetMovable(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	bar:SetBackdropColor(0.06, 0.07, 0.09, 0.65)
	bar:SetBackdropBorderColor(0.55, 0.48, 0.30, 0.85)
	bar:Hide()

	bar:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		local db = ns.GetDB and ns.GetDB()
		if db and point and relPoint then
			db.quickBarPos = {
				point = point,
				relPoint = relPoint,
				x = math.floor((ns.SafeNumber(x) or 0) + 0.5),
				y = math.floor((ns.SafeNumber(y) or 0) + 0.5),
			}
		end
		PositionCoordsFrame()
	end)
	bar:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and ns.ResetQuickBarPosition then
			ns.ResetQuickBarPosition()
		end
	end)
	AttachQuickTip(bar, "PureGrid Quick-Bar", "Left-Drag: Move toolbar\nRight-Click: Reset position to top-center")

	local x = 10

	-- Title grip
	local titleFS = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	titleFS:SetPoint("LEFT", bar, "LEFT", x, 0)
	titleFS:SetText("PureGrid")
	x = x + 52

	MakeDivider(bar, x)
	x = x + 6

	-- Spacing group: - 16px + (supports mousewheel)
	spMinusBtn = MakeFlatBtn(bar, "-", 16, function() StepSpacing(-1) end,
		"Decrease Grid Spacing", "Step spacing down (hold Shift for -2px).")
	spMinusBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 16

	local spWheel = CreateFrame("Frame", nil, bar)
	spWheel:SetSize(36, 18)
	spWheel:SetPoint("LEFT", bar, "LEFT", x, 0)
	spWheel:EnableMouse(true)
	spWheel:EnableMouseWheel(true)
	spWheel:SetScript("OnMouseWheel", function(_, delta) StepSpacing(delta > 0 and 1 or -1) end)
	AttachQuickTip(spWheel, "Grid Spacing", "Scroll mousewheel to adjust spacing (hold Shift for 2px steps).")

	spacingValFS = spWheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	spacingValFS:SetPoint("CENTER", spWheel, "CENTER", 0, 0)
	x = x + 36

	spPlusBtn = MakeFlatBtn(bar, "+", 16, function() StepSpacing(1) end,
		"Increase Grid Spacing", "Step spacing up (hold Shift for +2px).")
	spPlusBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 20

	MakeDivider(bar, x)
	x = x + 6

	-- Opacity group: - 10% + (supports mousewheel)
	opMinusBtn = MakeFlatBtn(bar, "-", 16, function() StepOpacity(-1) end,
		"Decrease Opacity", "Lower grid opacity by 10% (hold Shift for 5%).")
	opMinusBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 16

	local opWheel = CreateFrame("Frame", nil, bar)
	opWheel:SetSize(34, 18)
	opWheel:SetPoint("LEFT", bar, "LEFT", x, 0)
	opWheel:EnableMouse(true)
	opWheel:EnableMouseWheel(true)
	opWheel:SetScript("OnMouseWheel", function(_, delta) StepOpacity(delta > 0 and 1 or -1) end)
	AttachQuickTip(opWheel, "Grid Opacity", "Scroll mousewheel to adjust opacity (hold Shift for 5% steps).")

	alphaValFS = opWheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	alphaValFS:SetPoint("CENTER", opWheel, "CENTER", 0, 0)
	x = x + 34

	opPlusBtn = MakeFlatBtn(bar, "+", 16, function() StepOpacity(1) end,
		"Increase Opacity", "Raise grid opacity by 10% (hold Shift for 5%).")
	opPlusBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 20

	MakeDivider(bar, x)
	x = x + 6

	-- Mode toggles: Cross, Snap
	crossBtn = MakeFlatBtn(bar, "Cross", 38, function()
		local db = ns.GetDB and ns.GetDB()
		if not db then return end
		db.crosshairOnly = not db.crosshairOnly
		if ns.ForceRefresh then ns.ForceRefresh() end
		if ns.RefreshUI then ns.RefreshUI() end
	end, "Center Crosshair Only", "Toggle between full grid and red center crosshairs only.")
	crossBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 40

	snapBtn = MakeFlatBtn(bar, "Snap", 34, function()
		local db = ns.GetDB and ns.GetDB()
		if not db then return end
		db.snapToGrid = not db.snapToGrid
		if ns.UpdateQuickBar then ns.UpdateQuickBar() end
		if ns.RefreshUI then ns.RefreshUI() end
	end, "Snap Addon Frames", "Toggle Snap-on-Drop for non-protected movable addon frames (hold Shift while dropping to bypass).")
	snapBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 38

	MakeDivider(bar, x)
	x = x + 6

	-- Custom Guides: +V, +H, Edit, Clr
	local addVBtn = MakeFlatBtn(bar, "+V", 22, function()
		if ns.AddCustomGuide then
			ns.AddCustomGuide("V", 200, true)
			if ns.SetGuideEditMode then ns.SetGuideEditMode(true) end
		end
	end, "Add Vertical Guide", "Adds a mirrored vertical guide (±200 px) and unlocks drag handles.", "accent")
	addVBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 23

	local addHBtn = MakeFlatBtn(bar, "+H", 22, function()
		if ns.AddCustomGuide then
			ns.AddCustomGuide("H", -160, false)
			if ns.SetGuideEditMode then ns.SetGuideEditMode(true) end
		end
	end, "Add Horizontal Guide", "Adds a horizontal guide (-160 px) and unlocks drag handles.", "accent")
	addHBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 23

	editGuidesBtn = MakeFlatBtn(bar, "Edit", 30, function()
		if ns.SetGuideEditMode and ns.IsGuideEditMode then
			ns.SetGuideEditMode(not ns.IsGuideEditMode())
		end
	end, "Edit Custom Guides", "Unlock or lock draggable guide handles on screen (Right-Click a handle to delete, Alt-Click or Middle-Click to toggle Mirror).")
	editGuidesBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 31

	clearGuidesBtn = MakeFlatBtn(bar, "Clr", 24, function()
		if ns.ClearCustomGuides then ns.ClearCustomGuides() end
	end, "Clear All Guides", "Removes all custom guide lines.")
	clearGuidesBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 28

	MakeDivider(bar, x)
	x = x + 6

	-- Actions: Cfg, X
	local cfgBtn = MakeFlatBtn(bar, "Cfg", 26, function()
		if ns.ToggleSettings then
			ns.ToggleSettings()
		elseif ns.OpenSettings then
			ns.OpenSettings()
		end
	end, "Toggle Settings", "Open or close Options > AddOns > PureGrid.", "accent")
	cfgBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 28

	local hideBtn = MakeFlatBtn(bar, "X", 18, function()
		if ns.SetGridShown then ns.SetGridShown(false) end
	end, "Hide Grid", "Hide PureGrid overlay.", "close")
	hideBtn:SetPoint("LEFT", bar, "LEFT", x, 0)
	x = x + 24

	bar:SetWidth(x)
	quickBar = bar
	ApplyQuickBarPosition()

	-- Cursor Center-Offset Readout HUD
	local cf = CreateFrame("Frame", "PureGridCoordsFrame", UIParent, "BackdropTemplate")
	cf:SetSize(142, 20)
	cf:SetFrameStrata("DIALOG")
	cf:SetFrameLevel(19)
	cf:EnableMouse(false)
	cf:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	cf:SetBackdropColor(0.06, 0.07, 0.09, 0.65)
	cf:SetBackdropBorderColor(0.55, 0.48, 0.30, 0.85)
	cf:Hide()

	coordsText = cf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	coordsText:SetPoint("CENTER", cf, "CENTER", 0, 0)
	coordsText:SetText("|cffffd100X:|r 0   |cffffd100Y:|r 0")
	coordsFrame = cf

	ns.UpdateQuickBar()
end

function ns.UpdateQuickBar()
	if not quickBar then return end
	local db = ns.GetDB and ns.GetDB()
	local visible = ns.IsGridVisible and ns.IsGridVisible()

	if visible and db and db.showQuickBar ~= false then
		local curSize = db.gridSize or 16
		local curPct = math.floor((db.gridAlpha or 0.10) * 100 + 0.5)
		local hasGuides = type(db.guides) == "table" and #db.guides > 0
		local editing = ns.IsGuideEditMode and ns.IsGuideEditMode() or false

		spacingValFS:SetText(curSize .. "px")
		alphaValFS:SetText(curPct .. "%")
		if spMinusBtn then spMinusBtn:SetFlatEnabled(curSize > 8) end
		if spPlusBtn then spPlusBtn:SetFlatEnabled(curSize < 256) end
		if opMinusBtn then opMinusBtn:SetFlatEnabled(curPct > 10) end
		if opPlusBtn then opPlusBtn:SetFlatEnabled(curPct < 100) end
		if editGuidesBtn then editGuidesBtn:SetFlatEnabled(hasGuides or editing) end
		if clearGuidesBtn then clearGuidesBtn:SetFlatEnabled(hasGuides) end

		if crossBtn then crossBtn:SetFlatActive(db.crosshairOnly and true or false) end
		if snapBtn then snapBtn:SetFlatActive(db.snapToGrid and true or false) end
		if editGuidesBtn then editGuidesBtn:SetFlatActive(editing) end
		quickBar:Show()
	else
		quickBar:Hide()
	end

	if coordsFrame then
		if visible and db and db.showCursorCoords then
			PositionCoordsFrame()
			coordsElapsed = 0.05 -- force immediate update
			coordsFrame:SetScript("OnUpdate", CoordsOnUpdate)
			coordsFrame:Show()
		else
			coordsFrame:SetScript("OnUpdate", nil)
			coordsFrame:Hide()
		end
	end
end

function ns.ResetQuickBarPosition()
	local db = ns.GetDB and ns.GetDB()
	if not db then return end
	db.quickBarPos = nil
	ApplyQuickBarPosition()
	PositionCoordsFrame()
	print("|cff66ccffPureGrid:|r Quick-Bar position reset to top center.")
end
