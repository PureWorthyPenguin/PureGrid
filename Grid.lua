-- PureGrid: Pixel-perfect, pooled, combat-safe screen alignment grid engine.
local _, ns = ...

local overlay
local eventFrame
local vPool = {}
local hPool = {}
local centerV
local centerH

local gridDesired = false
local inCombat = false
local needsRebuild = true
local snapHooked = false
local isSnapping = false

local MAX_LINES_PER_SIDE = 400

local function ConfigureLineTexture(tex, layer, sublevel)
	tex:SetDrawLayer(layer, sublevel)
	if tex.SetSnapToPixelGrid then
		tex:SetSnapToPixelGrid(false)
	end
	return tex
end

local function AcquireLine(pool, idx)
	local tex = pool[idx]
	if not tex then
		tex = ConfigureLineTexture(overlay:CreateTexture(nil, "ARTWORK"), "ARTWORK", 1)
		pool[idx] = tex
	end
	return tex
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

	centerV = ConfigureLineTexture(overlay:CreateTexture(nil, "OVERLAY"), "OVERLAY", 7)
	centerH = ConfigureLineTexture(overlay:CreateTexture(nil, "OVERLAY"), "OVERLAY", 7)
	return overlay
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
	else
		overlay:SetAlpha(0)
		overlay:Hide()
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

	local width = ns.SafeNumber(overlay:GetWidth())
	local height = ns.SafeNumber(overlay:GetHeight())
	if not width or width <= 0 or not height or height <= 0 then
		local physW, physH = GetPhysicalScreenSize()
		width = ns.SafeNumber(physW) or 1920
		height = ns.SafeNumber(physH) or 1080
	end

	-- With IgnoreParentScale + scale = 768/physH, 1 unit == 1 physical pixel.
	-- Anchor odd thicknesses (1px, 3px) at k + 0.5 (pixel center) and even thicknesses (2px, 4px)
	-- at k + 0.0, with +0.15px safety margin so 1px lines never collapse to 0px on subpixel rounding.
	local gridSize = math.max(8, math.min(256, math.floor((db.gridSize or 8) + 0.5)))
	local thickness = math.max(1, math.min(4, math.floor((db.lineThickness or 1) + 0.5)))
	local lineSize = thickness + 0.15
	local halfPx = (thickness % 2 == 1) and 0.5 or 0.0
	local alpha = math.max(0.10, math.min(1.00, db.gridAlpha or 0.20))

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
	local centerAlpha = math.min(1.0, alpha + 0.25)

	-- Vertical lines radiating symmetrically from exact integer screen center
	local vPerSide = math.min(MAX_LINES_PER_SIDE, math.floor(centerX / gridSize))
	local vIdx = 0

	for i = 1, vPerSide do
		local offset = i * gridSize
		-- Right of center
		vIdx = vIdx + 1
		local rLine = AcquireLine(vPool, vIdx)
		rLine:ClearAllPoints()
		rLine:SetColorTexture(gr, gg, gb, alpha)
		rLine:SetSize(lineSize, height)
		rLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX + offset + halfPx, midY)
		rLine:Show()

		-- Left of center
		vIdx = vIdx + 1
		local lLine = AcquireLine(vPool, vIdx)
		lLine:ClearAllPoints()
		lLine:SetColorTexture(gr, gg, gb, alpha)
		lLine:SetSize(lineSize, height)
		lLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX - offset + halfPx, midY)
		lLine:Show()
	end

	for i = vIdx + 1, #vPool do
		vPool[i]:Hide()
	end

	-- Horizontal lines radiating symmetrically from exact integer screen center
	local hPerSide = math.min(MAX_LINES_PER_SIDE, math.floor(centerY / gridSize))
	local hIdx = 0

	for i = 1, hPerSide do
		local offset = i * gridSize
		-- Above center
		hIdx = hIdx + 1
		local tLine = AcquireLine(hPool, hIdx)
		tLine:ClearAllPoints()
		tLine:SetColorTexture(gr, gg, gb, alpha)
		tLine:SetSize(width, lineSize)
		tLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY + offset + halfPx)
		tLine:Show()

		-- Below center
		hIdx = hIdx + 1
		local bLine = AcquireLine(hPool, hIdx)
		bLine:ClearAllPoints()
		bLine:SetColorTexture(gr, gg, gb, alpha)
		bLine:SetSize(width, lineSize)
		bLine:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY - offset + halfPx)
		bLine:Show()
	end

	for i = hIdx + 1, #hPool do
		hPool[i]:Hide()
	end

	-- Center vertical & horizontal lines (red by default, rendered above normal lines)
	centerV:ClearAllPoints()
	centerV:SetColorTexture(cr, cg, cb, centerAlpha)
	centerV:SetSize(lineSize, height)
	centerV:SetPoint("CENTER", overlay, "BOTTOMLEFT", centerX + halfPx, midY)
	centerV:Show()

	centerH:ClearAllPoints()
	centerH:SetColorTexture(cr, cg, cb, centerAlpha)
	centerH:SetSize(width, lineSize)
	centerH:SetPoint("CENTER", overlay, "BOTTOMLEFT", midX, centerY + halfPx)
	centerH:Show()

	needsRebuild = false
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

local function NearestGridDelta(posP, centerP, gridSize)
	local snapped = centerP + math.floor(((posP - centerP) / gridSize) + 0.5) * gridSize
	return snapped - posP
end

local function PickSmallestDelta(a, b, c)
	local best = a
	if math.abs(b) < math.abs(best) then best = b end
	if math.abs(c) < math.abs(best) then best = c end
	return best
end

local function ShouldSkipSnapFrame(frame)
	if not ns.IsUsableFrame(frame) then return true end
	if frame == UIParent or frame == WorldFrame or frame == overlay then return true end
	if frame.IsProtected and frame:IsProtected() then return true end
	if frame.IsMovable and not frame:IsMovable() then return true end
	local name = frame.GetName and frame:GetName()
	if type(name) == "string" and not ns.IsSecret(name) then
		if name == "PureGridMinimapButton"
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
	local gridSize = math.max(8, math.min(256, math.floor((db.gridSize or 8) + 0.5)))

	local centerX = math.floor(physW * 0.5)
	local centerY = math.floor(physH * 0.5)

	local leftP = left * toPhys
	local rightP = right * toPhys
	local cxP = (leftP + rightP) * 0.5

	local bottomP = bottom * toPhys
	local topP = top * toPhys
	local cyP = (bottomP + topP) * 0.5

	local dxP = PickSmallestDelta(
		NearestGridDelta(leftP, centerX, gridSize),
		NearestGridDelta(cxP, centerX, gridSize),
		NearestGridDelta(rightP, centerX, gridSize)
	)
	local dyP = PickSmallestDelta(
		NearestGridDelta(bottomP, centerY, gridSize),
		NearestGridDelta(cyP, centerY, gridSize),
		NearestGridDelta(topP, centerY, gridSize)
	)

	local dx = dxP / toPhys
	local dy = dyP / toPhys
	if math.abs(dx) < 0.01 and math.abs(dy) < 0.01 then return end

	isSnapping = true
	pcall(function()
		frame:ClearAllPoints()
		frame:SetPoint(point, relativeTo, relativePoint, xOfs + dx, yOfs + dy)
	end)
	isSnapping = false
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

function ns.InitGrid()
	EnsureOverlay()
	InitSnapHook()
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
