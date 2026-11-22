-- PureGrid: Zero-dependency orbiting Minimap button (hidden by default).
local _, ns = ...

local minimapBtn
local isDragging = false

local function GetMinimapRadius()
	local w = ns.SafeNumber(Minimap and Minimap:GetWidth()) or 140
	return (w * 0.5) + 6
end

local function PositionButton(angleDeg)
	if not minimapBtn or not Minimap then
		return
	end
	local rad = math.rad(angleDeg or ns.DEFAULT_MINIMAP_ANGLE)
	local radius = GetMinimapRadius()
	local x = math.cos(rad) * radius
	local y = math.sin(rad) * radius

	minimapBtn:ClearAllPoints()
	minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateDragAngle()
	if not Minimap then
		return
	end
	local mx, my = Minimap:GetCenter()
	mx = ns.SafeNumber(mx)
	my = ns.SafeNumber(my)
	if not mx or not my then
		return
	end

	local cx, cy = GetCursorPosition()
	cx = ns.SafeNumber(cx)
	cy = ns.SafeNumber(cy)
	local scale = ns.SafeNumber(Minimap:GetEffectiveScale()) or 1
	if not cx or not cy or scale <= 0 then
		return
	end

	local dx = (cx / scale) - mx
	local dy = (cy / scale) - my
	local deg = math.deg(math.atan2(dy, dx))
	if deg < 0 then
		deg = deg + 360
	end

	local db = ns.GetDB and ns.GetDB()
	if db then
		db.minimapAngle = math.floor(deg + 0.5)
	end
	PositionButton(deg)
end

function ns.InitMinimapButton()
	if minimapBtn or not Minimap then
		return
	end

	local btn = CreateFrame("Button", "PureGridMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(0.05, 0.05, 0.08, 0.85)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Net_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.icon = icon

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	btn.border = border

	btn:SetScript("OnClick", function(_, button)
		if isDragging then
			return
		end
		if button == "RightButton" then
			if ns.OpenSettings then
				ns.OpenSettings()
			end
		else
			if ns.ToggleGrid then
				ns.ToggleGrid()
			end
		end
	end)

	btn:SetScript("OnDragStart", function(self)
		local db = ns.GetDB and ns.GetDB()
		if not db or db.lockMinimapButton then
			return
		end
		isDragging = true
		self:SetScript("OnUpdate", UpdateDragAngle)
	end)

	btn:SetScript("OnDragStop", function(self)
		isDragging = false
		self:SetScript("OnUpdate", nil)
	end)

	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("PureGrid", 1, 0.82, 0)
		local status = ns.GetGridStatusText and ns.GetGridStatusText() or "|cffff6666Hidden|r"
		GameTooltip:AddLine("Grid: " .. status, 1, 1, 1)
		GameTooltip:AddLine("Left-Click: Toggle Grid", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-Click: Open Settings", 0.8, 0.8, 0.8)
		local db = ns.GetDB and ns.GetDB()
		if db and not db.lockMinimapButton then
			GameTooltip:AddLine("Drag: Move Button", 0.65, 0.85, 1.0)
		end
		GameTooltip:Show()
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	minimapBtn = btn
	ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
	if not minimapBtn then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	if not db or not db.showMinimapButton then
		minimapBtn:Hide()
		return
	end
	PositionButton(db.minimapAngle or ns.DEFAULT_MINIMAP_ANGLE)
	if ns.IsGridDesired and ns.IsGridDesired() then
		minimapBtn.icon:SetVertexColor(0.55, 1.0, 0.55)
	else
		minimapBtn.icon:SetVertexColor(1.0, 1.0, 1.0)
	end
	minimapBtn:Show()
end

function ns.ResetMinimapButtonPosition()
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return false
	end
	db.minimapAngle = ns.DEFAULT_MINIMAP_ANGLE
	ns.UpdateMinimapButton()
	print("|cff66ccffPureGrid:|r Minimap button position reset to default.")
	return true
end
