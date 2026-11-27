-- PureGrid: Pixel-perfect, pooled, combat-safe screen alignment grid engine.
local _, ns = ...

local overlay
local eventFrame
local vPool = {}
local hPool = {}
local refPool = {}
local guideLinePool = {}
local guideHandlePool = {}
local centerV
local centerH
local flashV
local flashH
local flashFrame
local flashTimer = 0

local gridDesired = false
local inCombat = false
local needsRebuild = true
local guideEditMode = false
local snapHooked = false
local isSnapping = false
local editModeHooked = false
local blizzGridHooked = false
local editModeTicker = nil
local lastEditModeState = false
local inEditModeSession = false
local openedByEditMode = false
local blizzGridSuppressed = false
local cachedBlizzGrid = nil

local MAX_LINES_PER_SIDE = 400
local FLASH_DURATION = 0.35

local function ConfigureLineTexture(tex, layer, sublevel)
	tex:SetDrawLayer(layer, sublevel)
	if tex.SetSnapToPixelGrid then
		tex:SetSnapToPixelGrid(false)
	end
	return tex
end

local function AcquireLine(pool, idx, layer, sublevel)
	local tex = pool[idx]
	if not tex then
		tex = ConfigureLineTexture(overlay:CreateTexture(nil, layer or "ARTWORK"), layer or "ARTWORK", sublevel or 1)
		pool[idx] = tex
	end
	return tex
end

local function GetScreenDims()
	local width = overlay and ns.SafeNumber(overlay:GetWidth())
	local height = overlay and ns.SafeNumber(overlay:GetHeight())
	if not width or width <= 0 or not height or height <= 0 then
		local physW, physH = GetPhysicalScreenSize()
		width = ns.SafeNumber(physW) or 1920
		height = ns.SafeNumber(physH) or 1080
	end
	return width, height
end

local function UpdateOverlayScale()
	if not overlay then
		return
	end
	local _, physH = GetPhysicalScreenSize()
	physH = ns.SafeNumber(physH)
	if physH and physH > 0 then
		overlay:SetIgnoreParentScale(true)
		overlay:SetScale(768 / physH)
	else
		overlay:SetIgnoreParentScale(false)
		overlay:SetScale(1)
	end
end

local function EnsureOverlay()
	if overlay then
		return overlay
	end
	overlay = CreateFrame("Frame", "PureGridOverlayFrame", UIParent)
	overlay:SetAllPoints(UIParent)
	overlay:EnableMouse(false)
	overlay:SetFrameStrata("HIGH")
	overlay:SetFrameLevel(1)
	UpdateOverlayScale()
	overlay:Hide()

	centerV = ConfigureLineTexture(overlay:CreateTexture(nil, "OVERLAY"), "OVERLAY", 6)
	centerH = ConfigureLineTexture(overlay:CreateTexture(nil, "OVERLAY"), "OVERLAY", 6)

	flashV = ConfigureLineTexture(overlay:CreateTexture(nil, "OVERLAY"), "OVERLAY", 7)
	flashV:Hide()
	flashH = ConfigureLineTexture(overlay:CreateTexture(nil, "OVERLAY"), "OVERLAY", 7)
	flashH:Hide()

	return overlay
end

local function GetBlizzardEditGrid()
	if cachedBlizzGrid and ns.IsUsableFrame(cachedBlizzGrid) then
		return cachedBlizzGrid
	end
	local em = _G.EditModeManagerFrame
	if em and em.Grid and ns.IsUsableFrame(em.Grid) then
		cachedBlizzGrid = em.Grid
		return cachedBlizzGrid
	end
	if _G.EditModeGrid and ns.IsUsableFrame(_G.EditModeGrid) then
		cachedBlizzGrid = _G.EditModeGrid
		return cachedBlizzGrid
	end
	if em and em.GetChildren then
		local children = { em:GetChildren() }
		for i = 1, #children do
			local c = children[i]
			if ns.IsUsableFrame(c) and (type(c.UpdateGrid) == "function" or c.linePool ~= nil) then
				cachedBlizzGrid = c
				return cachedBlizzGrid
			end
		end
	end
	return nil
end

local function IsBlizzardEditModeActive()
	local em = _G.EditModeManagerFrame
	if not em then return false end
	if em.IsEditModeActive then
		local ok, active = pcall(em.IsEditModeActive, em)
		if ok and active then return true end
	end
	return ns.SafeBool(em:IsShown())
end

-- Suppress / restore Blizzard's Edit Mode Grid cleanly via SetAlpha (zero taint)
local function SyncBlizzardEditGrid()
	local bGrid = GetBlizzardEditGrid()
	if not bGrid then return end

	if not blizzGridHooked then
		blizzGridHooked = true
		pcall(function()
			if type(bGrid.Show) == "function" then
				hooksecurefunc(bGrid, "Show", function() SyncBlizzardEditGrid() end)
			end
			if type(bGrid.SetShown) == "function" then
				hooksecurefunc(bGrid, "SetShown", function() SyncBlizzardEditGrid() end)
			end
			if type(bGrid.UpdateGrid) == "function" then
				hooksecurefunc(bGrid, "UpdateGrid", function() SyncBlizzardEditGrid() end)
			end
		end)
	end

	local db = ns.GetDB and ns.GetDB()
	local inEditMode = IsBlizzardEditModeActive()
	local shouldSuppress = inEditMode and ns.IsGridVisible() and db and db.hideBlizzardEditGrid ~= false

	if shouldSuppress then
		bGrid:SetAlpha(0)
		blizzGridSuppressed = true
	elseif blizzGridSuppressed then
		bGrid:SetAlpha(1)
		blizzGridSuppressed = false
	end
end

local function HideAllGuideHandles()
	for i = 1, #guideHandlePool do
		guideHandlePool[i]:SetScript("OnUpdate", nil)
		guideHandlePool[i]:Hide()
	end
end

local function AcquireGuideHandle(idx)
	local btn = guideHandlePool[idx]
	if btn then return btn end

	btn = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
	btn:SetSize(22, 18)
	btn:SetFrameStrata("DIALOG")
	btn:SetFrameLevel(25)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 12, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	btn:SetBackdropColor(0.08, 0.14, 0.18, 0.94)
	btn:SetBackdropBorderColor(0.95, 0.78, 0.25, 0.95)

	btn.tag = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	btn.tag:SetPoint("CENTER", btn, "CENTER", 0, 0)

	btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	btn.label:SetPoint("LEFT", btn, "RIGHT", 4, 0)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Custom Guide Handle", 1, 0.82, 0)
		GameTooltip:AddLine("Left-Drag: Move guide (snaps to grid; hold Shift for 1px)", 1, 1, 1)
		GameTooltip:AddLine("Alt+Click or Middle-Click: Toggle Mirror (±)", 0.8, 0.9, 1.0)
		GameTooltip:AddLine("Right-Click: Delete guide", 1.0, 0.5, 0.5)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	btn:Hide()
	guideHandlePool[idx] = btn
	return btn
end

local function RefreshCustomGuides(width, height, centerX, centerY, midX, midY, lineSize, halfPx)
	local db = ns.GetDB and ns.GetDB()
	local guides = db and db.guides
	local gIdx = 0

	local gc = (db and db.guideColor) or { r = 0.0, g = 0.9, b = 1.0 }
	local r, g, b = gc.r or 0.0, gc.g or 0.9, gc.b or 1.0
	local guideAlpha = 0.80

	local showHandles = guideEditMode and ns.IsGridVisible() and not inCombat
	local uiScale = ns.SafeNumber(UIParent:GetEffectiveScale()) or 1
	local _, physH = GetPhysicalScreenSize()
	physH = ns.SafeNumber(physH) or height
	local physToUI = (768 / physH) / uiScale

	if type(guides) == "table" then
		for idx, entry in ipairs(guides) do
			if idx > ns.MAX_CUSTOM_GUIDES then break end
			local axis = (entry.axis == "H") and "H" or "V"
			local offset = math.floor((ns.SafeNumber(entry.offset) or 0) + 0.5)
			local mirror = entry.mirror and true or false

			if axis == "V" then
				gIdx = gIdx + 1
				local l1 = AcquireLine(guideLinePool, gIdx, "OVERLAY", 5)
				l1:ClearAllPoints()
				l1:SetColorTexture(r, g, b, guideAlpha)
				l1:SetSize(lineSize, height)
				l1:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX + offset + halfPx, midY)
				l1:Show()

				if mirror and offset ~= 0 then
					gIdx = gIdx + 1
					local l2 = AcquireLine(guideLinePool, gIdx, "OVERLAY", 5)
					l2:ClearAllPoints()
					l2:SetColorTexture(r, g, b, guideAlpha)
					l2:SetSize(lineSize, height)
					l2:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX - offset + halfPx, midY)
					l2:Show()
				end
			else
				gIdx = gIdx + 1
				local l1 = AcquireLine(guideLinePool, gIdx, "OVERLAY", 5)
				l1:ClearAllPoints()
				l1:SetColorTexture(r, g, b, guideAlpha)
				l1:SetSize(width, lineSize)
				l1:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY + offset + halfPx)
				l1:Show()

				if mirror and offset ~= 0 then
					gIdx = gIdx + 1
					local l2 = AcquireLine(guideLinePool, gIdx, "OVERLAY", 5)
					l2:ClearAllPoints()
					l2:SetColorTexture(r, g, b, guideAlpha)
					l2:SetSize(width, lineSize)
					l2:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY - offset + halfPx)
					l2:Show()
				end
			end

			if showHandles then
				local h = AcquireGuideHandle(idx)
				h.guideIndex = idx
				h.tag:SetText(axis)
				local prefix = mirror and "±" or (offset >= 0 and "+" or "")
				local shownOff = mirror and math.abs(offset) or offset
				h.label:SetText(string.format("|cff00e5ff%s%d px|r", prefix, shownOff))

				h:ClearAllPoints()
				if axis == "V" then
					local uiX = (centerX + offset) * physToUI
					h:SetPoint("TOP", UIParent, "BOTTOMLEFT", uiX, (height * physToUI) - 52)
					h.label:ClearAllPoints()
					h.label:SetPoint("TOP", h, "BOTTOM", 0, -2)
				else
					local uiY = (centerY + offset) * physToUI
					h:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 10, uiY)
					h.label:ClearAllPoints()
					h.label:SetPoint("LEFT", h, "RIGHT", 4, 0)
				end

				h:SetScript("OnClick", function(_, button)
					if button == "RightButton" then
						ns.RemoveCustomGuide(idx)
					elseif button == "MiddleButton" or (button == "LeftButton" and IsAltKeyDown and IsAltKeyDown()) then
						ns.ToggleGuideMirror(idx)
					end
				end)

				h:SetScript("OnDragStart", function(self)
					self:SetScript("OnUpdate", function()
						local cx, cy = GetCursorPosition()
						cx = ns.SafeNumber(cx)
						cy = ns.SafeNumber(cy)
						if not cx or not cy then return end
						local pW, pH = GetPhysicalScreenSize()
						pW = ns.SafeNumber(pW) or width
						pH = ns.SafeNumber(pH) or height
						local curDB = ns.GetDB and ns.GetDB()
						local gEntry = curDB and curDB.guides and curDB.guides[self.guideIndex]
						if not gEntry then return end

						-- GetCursorPosition() returns 768-height virtual coords; convert to physical pixels
						local toPhys = pH / 768
						local rawOff
						if gEntry.axis == "H" then
							rawOff = (cy * toPhys) - math.floor(pH * 0.5)
						else
							rawOff = (cx * toPhys) - math.floor(pW * 0.5)
						end

						if not (IsShiftKeyDown and IsShiftKeyDown()) then
							local step = math.max(8, math.min(256, math.floor((curDB.gridSize or 8) + 0.5)))
							rawOff = math.floor((rawOff / step) + 0.5) * step
						else
							rawOff = math.floor(rawOff + 0.5)
						end

						if rawOff ~= gEntry.offset then
							gEntry.offset = rawOff
							ns.RebuildGrid()
						end
					end)
				end)

				h:SetScript("OnDragStop", function(self)
					self:SetScript("OnUpdate", nil)
					if ns.RefreshUI then ns.RefreshUI() end
				end)

				h:Show()
			end
		end
	end

	for i = gIdx + 1, #guideLinePool do
		guideLinePool[i]:Hide()
	end

	local activeCount = (showHandles and type(guides) == "table") and math.min(#guides, ns.MAX_CUSTOM_GUIDES) or 0
	for i = activeCount + 1, #guideHandlePool do
		guideHandlePool[i]:SetScript("OnUpdate", nil)
		guideHandlePool[i]:Hide()
	end
end

local function ApplyVisibility()
	if not overlay then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local keepInCombat = db and db.keepInCombat and true or false
	local shouldShow = gridDesired and (keepInCombat or not inCombat)

	if shouldShow then
		if needsRebuild then
			ns.RebuildGrid()
		end
		overlay:SetAlpha(1)
		overlay:Show()
		if guideEditMode and not inCombat then
			ns.RebuildGrid()
		end
	else
		overlay:SetAlpha(0)
		overlay:Hide()
		HideAllGuideHandles()
	end

	SyncBlizzardEditGrid()

	if ns.UpdateQuickBar then
		ns.UpdateQuickBar()
	end
end

function ns.RebuildGrid()
	EnsureOverlay()
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return
	end

	UpdateOverlayScale()
	overlay:SetFrameStrata(db.strata or "HIGH")

	local width, height = GetScreenDims()

	-- With IgnoreParentScale + scale = 768/physH, 1 unit == 1 physical pixel.
	-- Anchor odd thicknesses (1px, 3px) at k + 0.5 (pixel center) and even thicknesses (2px, 4px)
	-- at k + 0.0, with +0.15px safety margin so 1px lines never collapse to 0px on subpixel rounding.
	local gridSize = math.max(8, math.min(256, math.floor((db.gridSize or 16) + 0.5)))
	local thickness = math.max(1, math.min(4, math.floor((db.lineThickness or 1) + 0.5)))
	local lineSize = thickness + 0.15
	local halfPx = (thickness % 2 == 1) and 0.5 or 0.0
	local alpha = math.max(0.10, math.min(1.00, db.gridAlpha or 0.10))

	local majorEnabled = db.majorLineEnabled ~= false
	local majorInterval = math.max(2, math.min(16, math.floor((db.majorLineInterval or 5) + 0.5)))

	local centerThickness = math.max(1, math.min(4, math.floor((db.centerThickness or 1) + 0.5)))
	local centerSize = centerThickness + 0.15
	local centerHalfPx = (centerThickness % 2 == 1) and 0.5 or 0.0
	local centerAlpha = math.max(0.10, math.min(1.00, db.centerAlpha or 0.50))

	local centerX = math.floor(width * 0.5)
	local centerY = math.floor(height * 0.5)
	local midX = width * 0.5
	local midY = height * 0.5

	local gc = db.gridColor or { r = 1, g = 1, b = 1 }
	local gr = gc.r or 1
	local gg = gc.g or 1
	local gb = gc.b or 1

	local cc = db.centerColor or { r = 1, g = 0.15, b = 0.15 }
	local cr = cc.r or 1
	local cg = cc.g or 0.15
	local cb = cc.b or 0.15

	-- Normal & Major Grid Lines (skipped in Center Crosshair-Only mode)
	local vIdx = 0
	local hIdx = 0
	if not db.crosshairOnly then
		local vPerSide = math.min(MAX_LINES_PER_SIDE, math.floor(centerX / gridSize))
		for i = 1, vPerSide do
			local offset = i * gridSize
			local isMajor = majorEnabled and (i % majorInterval == 0)
			local lineA = isMajor and centerAlpha or alpha
			local curSize = isMajor and centerSize or lineSize
			local curHalf = isMajor and centerHalfPx or halfPx

			vIdx = vIdx + 1
			local rLine = AcquireLine(vPool, vIdx, "ARTWORK", 1)
			rLine:ClearAllPoints()
			rLine:SetColorTexture(gr, gg, gb, lineA)
			rLine:SetSize(curSize, height)
			rLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX + offset + curHalf, midY)
			rLine:Show()

			vIdx = vIdx + 1
			local lLine = AcquireLine(vPool, vIdx, "ARTWORK", 1)
			lLine:ClearAllPoints()
			lLine:SetColorTexture(gr, gg, gb, lineA)
			lLine:SetSize(curSize, height)
			lLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX - offset + curHalf, midY)
			lLine:Show()
		end

		local hPerSide = math.min(MAX_LINES_PER_SIDE, math.floor(centerY / gridSize))
		for i = 1, hPerSide do
			local offset = i * gridSize
			local isMajor = majorEnabled and (i % majorInterval == 0)
			local lineA = isMajor and centerAlpha or alpha
			local curSize = isMajor and centerSize or lineSize
			local curHalf = isMajor and centerHalfPx or halfPx

			hIdx = hIdx + 1
			local tLine = AcquireLine(hPool, hIdx, "ARTWORK", 1)
			tLine:ClearAllPoints()
			tLine:SetColorTexture(gr, gg, gb, lineA)
			tLine:SetSize(width, curSize)
			tLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY + offset + curHalf)
			tLine:Show()

			hIdx = hIdx + 1
			local bLine = AcquireLine(hPool, hIdx, "ARTWORK", 1)
			bLine:ClearAllPoints()
			bLine:SetColorTexture(gr, gg, gb, lineA)
			bLine:SetSize(width, curSize)
			bLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY - offset + curHalf)
			bLine:Show()
		end
	end

	for i = vIdx + 1, #vPool do vPool[i]:Hide() end
	for i = hIdx + 1, #hPool do hPool[i]:Hide() end

	-- Screen Reference Guides (Rule of Thirds / Quarters)
	local refMode = db.referenceGuide or "none"
	local rIdx = 0
	if refMode == "thirds" or refMode == "quarters" then
		local frac1 = (refMode == "thirds") and (1 / 3) or 0.25
		local frac2 = (refMode == "thirds") and (2 / 3) or 0.75
		local refAlpha = math.min(0.85, alpha + 0.30)
		local vx1 = math.floor(width * frac1)
		local vx2 = math.floor(width * frac2)
		local hy1 = math.floor(height * frac1)
		local hy2 = math.floor(height * frac2)

		local vPos = { vx1, vx2 }
		for _, px in ipairs(vPos) do
			rIdx = rIdx + 1
			local rl = AcquireLine(refPool, rIdx, "OVERLAY", 4)
			rl:ClearAllPoints()
			rl:SetColorTexture(1.0, 0.82, 0.20, refAlpha)
			rl:SetSize(lineSize, height)
			rl:SetPoint("CENTER", overlay, "BOTTOMLEFT", px + halfPx, midY)
			rl:Show()
		end

		local hPos = { hy1, hy2 }
		for _, py in ipairs(hPos) do
			rIdx = rIdx + 1
			local rl = AcquireLine(refPool, rIdx, "OVERLAY", 4)
			rl:ClearAllPoints()
			rl:SetColorTexture(1.0, 0.82, 0.20, refAlpha)
			rl:SetSize(width, lineSize)
			rl:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, py + halfPx)
			rl:Show()
		end
	end
	for i = rIdx + 1, #refPool do refPool[i]:Hide() end

	-- Custom Mirrored Guide Lines & Optional Drag Handles
	RefreshCustomGuides(width, height, centerX, centerY, midX, midY, lineSize, halfPx)

	-- Center vertical & horizontal lines (independent opacity & thickness)
	centerV:ClearAllPoints()
	centerV:SetColorTexture(cr, cg, cb, centerAlpha)
	centerV:SetSize(centerSize, height)
	centerV:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX + centerHalfPx, midY)
	centerV:Show()

	centerH:ClearAllPoints()
	centerH:SetColorTexture(cr, cg, cb, centerAlpha)
	centerH:SetSize(width, centerSize)
	centerH:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY + centerHalfPx)
	centerH:Show()

	needsRebuild = false
end

-- Custom Guide Management API
function ns.AddCustomGuide(axis, offset, mirror)
	local db = ns.GetDB and ns.GetDB()
	if not db then return false end
	if type(db.guides) ~= "table" then db.guides = {} end
	if #db.guides >= ns.MAX_CUSTOM_GUIDES then
		print("|cff66ccffPureGrid:|r Maximum of " .. ns.MAX_CUSTOM_GUIDES .. " custom guides reached. Right-click a guide handle or click Clear All to remove one.")
		return false
	end
	db.guides[#db.guides + 1] = {
		axis = (axis == "H") and "H" or "V",
		offset = math.floor((ns.SafeNumber(offset) or 200) + 0.5),
		mirror = mirror and true or false,
	}
	if not gridDesired then
		ns.SetGridShown(true, true)
	end
	ns.ForceRefresh()
	if ns.RefreshUI then ns.RefreshUI() end
	return true
end

function ns.RemoveCustomGuide(idx)
	local db = ns.GetDB and ns.GetDB()
	if not db or type(db.guides) ~= "table" or not db.guides[idx] then return end
	table.remove(db.guides, idx)
	if #db.guides == 0 then
		guideEditMode = false
	end
	ns.ForceRefresh()
	if ns.RefreshUI then ns.RefreshUI() end
end

function ns.ToggleGuideMirror(idx)
	local db = ns.GetDB and ns.GetDB()
	if not db or type(db.guides) ~= "table" or not db.guides[idx] then return end
	db.guides[idx].mirror = not db.guides[idx].mirror
	ns.ForceRefresh()
	if ns.RefreshUI then ns.RefreshUI() end
end

function ns.ClearCustomGuides()
	local db = ns.GetDB and ns.GetDB()
	if not db then return end
	db.guides = {}
	guideEditMode = false
	HideAllGuideHandles()
	ns.ForceRefresh()
	if ns.RefreshUI then ns.RefreshUI() end
end

function ns.IsGuideEditMode()
	return guideEditMode
end

function ns.SetGuideEditMode(enabled)
	guideEditMode = enabled and true or false
	if guideEditMode and not gridDesired then
		ns.SetGridShown(true, true)
	end
	if not guideEditMode then
		HideAllGuideHandles()
	end
	ns.ForceRefresh()
	if ns.UpdateQuickBar then ns.UpdateQuickBar() end
	if ns.RefreshUI then ns.RefreshUI() end
end

function ns.IsGridDesired()
	return gridDesired
end

function ns.IsGridVisible()
	return overlay ~= nil and overlay:IsShown() and (ns.SafeNumber(overlay:GetAlpha()) or 0) > 0
end

function ns.GetGridStatusText()
	if not gridDesired then
		return "|cffff6666Hidden|r"
	end
	local db = ns.GetDB and ns.GetDB()
	if inCombat and not (db and db.keepInCombat) then
		return "|cffffcc00Paused in Combat|r"
	end
	return "|cff66ff66Shown|r"
end

function ns.SetGridShown(shown, silent)
	gridDesired = shown and true or false
	if not gridDesired then
		openedByEditMode = false
		guideEditMode = false
	end
	if PureGridDB then
		PureGridDB.lastGridShown = gridDesired
	end

	ApplyVisibility()

	if ns.UpdateMinimapButton then
		ns.UpdateMinimapButton()
	end
	if ns.RefreshUI then
		ns.RefreshUI()
	end

	if not silent then
		local db = ns.GetDB and ns.GetDB()
		if gridDesired and inCombat and not (db and db.keepInCombat) then
			print("|cff66ccffPureGrid:|r Grid enabled (will appear after combat ends).")
		end
	end
end

function ns.ToggleGrid(silent)
	ns.SetGridShown(not gridDesired, silent)
end

function ns.ForceRefresh()
	needsRebuild = true
	if overlay and gridDesired then
		ns.RebuildGrid()
	end
	ApplyVisibility()
	if ns.UpdateMinimapButton then
		ns.UpdateMinimapButton()
	end
	if ns.UpdateCompartmentButton then
		ns.UpdateCompartmentButton()
	end
end

-- Snap-on-Drop visual flash animation
local function TriggerSnapFlash(snappedXP, snappedYP, width, height)
	if not overlay or not flashV or not flashH then return end
	local db = ns.GetDB and ns.GetDB()
	if not db or db.snapFlash == false then return end

	if snappedXP then
		flashV:ClearAllPoints()
		flashV:SetColorTexture(1.0, 0.85, 0.15, 0.95)
		flashV:SetSize(2.15, height)
		flashV:SetPoint("CENTER", overlay, "BOTTOMLEFT", snappedXP, height * 0.5)
		flashV:Show()
	else
		flashV:Hide()
	end

	if snappedYP then
		flashH:ClearAllPoints()
		flashH:SetColorTexture(1.0, 0.85, 0.15, 0.95)
		flashH:SetSize(width, 2.15)
		flashH:SetPoint("CENTER", overlay, "BOTTOMLEFT", width * 0.5, snappedYP)
		flashH:Show()
	else
		flashH:Hide()
	end

	if not flashFrame then
		flashFrame = CreateFrame("Frame")
	end
	flashTimer = FLASH_DURATION
	flashFrame:SetScript("OnUpdate", function(self, elapsed)
		flashTimer = flashTimer - (elapsed or 0)
		if flashTimer <= 0 then
			flashV:Hide()
			flashH:Hide()
			self:SetScript("OnUpdate", nil)
		else
			local a = (flashTimer / FLASH_DURATION) * 0.95
			flashV:SetAlpha(a)
			flashH:SetAlpha(a)
		end
	end)
end

local function NearestGridLine(posP, centerP, gridSize)
	local snapped = centerP + math.floor(((posP - centerP) / gridSize) + 0.5) * gridSize
	return snapped - posP, snapped
end

local function PickBestSnap(candidates)
	local bestD, bestLine
	for i = 1, #candidates do
		local d = candidates[i][1]
		local line = candidates[i][2]
		if bestD == nil or math.abs(d) < math.abs(bestD) then
			bestD = d
			bestLine = line
		end
	end
	return bestD or 0, bestLine
end

local function ShouldSkipSnapFrame(frame)
	if not ns.IsUsableFrame(frame) then return true end
	if frame == UIParent or frame == WorldFrame or frame == overlay then return true end
	if frame.IsProtected and frame:IsProtected() then return true end
	if frame.IsMovable and not frame:IsMovable() then return true end
	local name = frame.GetName and frame:GetName()
	if type(name) == "string" and not ns.IsSecret(name) then
		if name == "PureGridMinimapButton"
			or name == "PureGridQuickBar"
			or name:sub(1, 8) == "EditMode"
			or name:sub(1, 13) == "SettingsPanel"
			or name:sub(1, 11) == "StaticPopup" then
			return true
		end
	end
	return false
end

local function SnapFrameToGrid(frame)
	if isSnapping then return end
	local db = ns.GetDB and ns.GetDB()
	if not db or not db.snapToGrid then return end
	if not ns.IsGridVisible() then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if IsShiftKeyDown and IsShiftKeyDown() then return end
	if ShouldSkipSnapFrame(frame) then return end
	if not frame.GetNumPoints or frame:GetNumPoints() ~= 1 then return end

	local fScale = ns.SafeNumber(frame.GetEffectiveScale and frame:GetEffectiveScale())
	if not fScale or fScale <= 0 then return end

	local physW, physH = GetPhysicalScreenSize()
	physW = ns.SafeNumber(physW)
	physH = ns.SafeNumber(physH)
	if not physW or physW <= 0 or not physH or physH <= 0 then return end

	local left = ns.SafeNumber(frame:GetLeft())
	local right = ns.SafeNumber(frame:GetRight())
	local bottom = ns.SafeNumber(frame:GetBottom())
	local top = ns.SafeNumber(frame:GetTop())
	if not left or not right or not bottom or not top then return end

	local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
	xOfs = ns.SafeNumber(xOfs)
	yOfs = ns.SafeNumber(yOfs)
	if not point or not xOfs or not yOfs then return end

	local overlayScale = 768 / physH
	local toPhys = fScale / overlayScale
	local gridSize = math.max(8, math.min(256, math.floor((db.gridSize or 16) + 0.5)))

	local centerX = math.floor(physW * 0.5)
	local centerY = math.floor(physH * 0.5)

	local leftP = left * toPhys
	local rightP = right * toPhys
	local cxP = (leftP + rightP) * 0.5

	local bottomP = bottom * toPhys
	local topP = top * toPhys
	local cyP = (bottomP + topP) * 0.5

	local snapMode = db.snapMode or "edges"
	local xCands, yCands = {}, {}

	if snapMode == "center" then
		local dxC, lxC = NearestGridLine(cxP, centerX, gridSize)
		local dyC, lyC = NearestGridLine(cyP, centerY, gridSize)
		xCands[1] = { dxC, lxC }
		yCands[1] = { dyC, lyC }
	elseif snapMode == "edges" then
		local dxL, lxL = NearestGridLine(leftP, centerX, gridSize)
		local dxR, lxR = NearestGridLine(rightP, centerX, gridSize)
		local dyB, lyB = NearestGridLine(bottomP, centerY, gridSize)
		local dyT, lyT = NearestGridLine(topP, centerY, gridSize)
		xCands[1] = { dxL, lxL }; xCands[2] = { dxR, lxR }
		yCands[1] = { dyB, lyB }; yCands[2] = { dyT, lyT }
	else
		local dxL, lxL = NearestGridLine(leftP, centerX, gridSize)
		local dxC, lxC = NearestGridLine(cxP, centerX, gridSize)
		local dxR, lxR = NearestGridLine(rightP, centerX, gridSize)
		local dyB, lyB = NearestGridLine(bottomP, centerY, gridSize)
		local dyC, lyC = NearestGridLine(cyP, centerY, gridSize)
		local dyT, lyT = NearestGridLine(topP, centerY, gridSize)
		xCands[1] = { dxL, lxL }; xCands[2] = { dxC, lxC }; xCands[3] = { dxR, lxR }
		yCands[1] = { dyB, lyB }; yCands[2] = { dyC, lyC }; yCands[3] = { dyT, lyT }
	end

	local dxP, snappedX = PickBestSnap(xCands)
	local dyP, snappedY = PickBestSnap(yCands)

	local dx = dxP / toPhys
	local dy = dyP / toPhys
	if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return end

	isSnapping = true
	pcall(function()
		frame:ClearAllPoints()
		frame:SetPoint(point, relativeTo, relativePoint, xOfs + dx, yOfs + dy)
	end)
	isSnapping = false

	TriggerSnapFlash(snappedX, snappedY, physW, physH)
end

local function InitSnapHook()
	if snapHooked then return end
	local mt = getmetatable(overlay)
	local idx = mt and mt.__index
	if type(idx) == "table" and type(idx.StopMovingOrSizing) == "function" then
		hooksecurefunc(idx, "StopMovingOrSizing", SnapFrameToGrid)
		snapHooked = true
	end
end

local function OnEditModeEnter()
	if inEditModeSession then
		SyncBlizzardEditGrid()
		return
	end
	inEditModeSession = true
	lastEditModeState = true

	local db = ns.GetDB and ns.GetDB()
	if db and db.autoShowInEditMode then
		if not gridDesired then
			openedByEditMode = true
			ns.SetGridShown(true, true)
		else
			openedByEditMode = false
			SyncBlizzardEditGrid()
		end
	else
		SyncBlizzardEditGrid()
	end
end

local function OnEditModeExit()
	if not inEditModeSession then
		SyncBlizzardEditGrid()
		return
	end
	inEditModeSession = false
	lastEditModeState = false

	if openedByEditMode then
		openedByEditMode = false
		ns.SetGridShown(false, true)
	else
		SyncBlizzardEditGrid()
	end
end

local eventRegistryHooked = false

function ns.TryHookEditMode()
	if not eventRegistryHooked and EventRegistry and EventRegistry.RegisterCallback then
		eventRegistryHooked = true
		pcall(function()
			EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter, "PureGrid_EditModeEnter")
			EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit, "PureGrid_EditModeExit")
		end)
	end

	local em = _G.EditModeManagerFrame
	if not editModeHooked and em then
		editModeHooked = true
		pcall(function()
			em:HookScript("OnShow", OnEditModeEnter)
			em:HookScript("OnHide", OnEditModeExit)
			if type(em.EnterEditMode) == "function" then
				hooksecurefunc(em, "EnterEditMode", OnEditModeEnter)
			end
			if type(em.ExitEditMode) == "function" then
				hooksecurefunc(em, "ExitEditMode", OnEditModeExit)
			end
		end)
		SyncBlizzardEditGrid()
	end
end

local function PollEditModeState()
	local db = ns.GetDB and ns.GetDB()
	if not db then return end
	if not db.autoShowInEditMode and not blizzGridSuppressed and not gridDesired then
		lastEditModeState = false
		return
	end
	local emOpen = IsBlizzardEditModeActive()
	if emOpen ~= lastEditModeState then
		lastEditModeState = emOpen
		if emOpen then
			OnEditModeEnter()
		else
			OnEditModeExit()
		end
	elseif emOpen then
		SyncBlizzardEditGrid()
	end
end

local function InitEditModeHook()
	ns.TryHookEditMode()
	if not editModeTicker and C_Timer and C_Timer.NewTicker then
		editModeTicker = C_Timer.NewTicker(0.25, PollEditModeState)
	end
end

function ns.InitGrid()
	EnsureOverlay()
	InitSnapHook()
	InitEditModeHook()
	inCombat = ns.SafeBool(InCombatLockdown and InCombatLockdown())

	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
		eventFrame:RegisterEvent("UI_SCALE_CHANGED")
		eventFrame:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_DISABLED" then
				inCombat = true
				if guideEditMode then
					guideEditMode = false
					HideAllGuideHandles()
				end
				ApplyVisibility()
				if ns.RefreshUI then ns.RefreshUI() end
			elseif event == "PLAYER_REGEN_ENABLED" then
				inCombat = false
				ApplyVisibility()
				if ns.RefreshUI then ns.RefreshUI() end
			elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
				needsRebuild = true
				if gridDesired then
					ns.RebuildGrid()
					ApplyVisibility()
				end
			end
		end)
	end

	local db = ns.GetDB and ns.GetDB()
	if db and db.rememberState and PureGridDB and PureGridDB.lastGridShown then
		gridDesired = true
	else
		gridDesired = false
	end

	ApplyVisibility()
end
