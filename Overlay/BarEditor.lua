-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...

addonTable.overlay = addonTable.overlay or {}

local function GetNeuron()
	return addonTable.Neuron
end

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")

---type definition the contents of the xml file
---@class NeuronBarFrame:CheckButton,ScriptObject
---@field Text FontString
---@field Message FontString
---@field MessageBG Texture

---@class BarOverlay
---@field active boolean
---@field bar Bar
---@field frame NeuronBarFrame
---@field microadjust number
---@field dragging boolean
---@field onClick fun(overlay: BarOverlay, button:string, down: boolean):nil

---@type NeuronBarFrame[]
local framePool = {}

local DRAG_THRESHOLD_SQ = 16

--- Bar editor overlays must NOT use SecureHandlerStateTemplate; 3.3.5 blocks
--- StartMoving on secure frames, which prevents drag-to-reposition.
local function createBarOverlayFrame()
	local frame = CreateFrame("Button", nil, UIParent)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)

	if not frame.Text then
		frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.Text:SetPoint("BOTTOM", frame, "TOP", 0, 1)
	end

	if not frame.MessageBG then
		frame.MessageBG = frame:CreateTexture(nil, "BACKGROUND")
		frame.MessageBG:SetColorTexture(0, 0, 0, 0.9)
	end

	if not frame.Message then
		frame.Message = frame:CreateFontString(nil, "OVERLAY", "FriendsFont_UserText")
		frame.Message:SetPoint("TOP", frame, "BOTTOM", 0, -1)
		frame.Message:SetJustifyV("TOP")
	end

	return frame
end

local function barAnchorPoint(bar)
	local point = bar.data.point or "CENTER"
	if point:find("SnapTo") then
		point = "CENTER"
	end
	return point
end

--- Position overlay from saved bar coordinates. Do not use SetAllPoints(bar):
--- anchoring a non-secure frame to a SecureHandler bar fails on 3.3.5 and
--- leaves the overlay at UIParent's default (top-right).
---@param overlay BarOverlay
local function syncOverlayToBar(overlay)
	local bar = overlay.bar
	overlay.frame:ClearAllPoints()
	overlay.frame:SetSize(bar:GetWidth(), bar:GetHeight())

	-- While dragging, the bar moves via SetPoint but saved x/y are not updated
	-- until mouse-up; follow the bar's live center so the highlight stays aligned.
	if overlay.dragging then
		local cx, cy = bar:GetCenter()
		if cx and cy then
			overlay.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
			return
		end
	end

	local point = barAnchorPoint(bar)
	overlay.frame:SetPoint("CENTER", UIParent, point, bar:GetXAxis() or 0, bar:GetYAxis() or 0)
end

local function cursorUIParentXY()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	return x / scale, y / scale
end

---@param overlay BarOverlay
local function stopBarDrag(overlay)
	overlay.dragging = false
	overlay.dragPending = false
	overlay.frame:SetScript("OnUpdate", nil)
end

---@param overlay BarOverlay
local function dragBarToCursor(overlay)
	local x, y = cursorUIParentXY()
	overlay.bar:SetUserPlaced(false)
	overlay.bar:ClearAllPoints()
	overlay.bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	syncOverlayToBar(overlay)
end

-- forward declare it so the event handlers can use it
local BarEditor

---@param overlay BarOverlay
local function updateAppearance(overlay)
	local concealed = overlay.bar:GetBarConceal()
	if concealed and overlay.active then
		overlay.frame:SetBackdropColor(1,0,0,0.6)
		overlay.frame.Text:Show()
	elseif not concealed and overlay.active then
		overlay.frame:SetBackdropColor(0,0,1,0.5)
		overlay.frame.Text:Show()
	elseif concealed and not overlay.active then
		overlay.frame:SetBackdropColor(1,0,0,0.4)
		overlay.frame.Text:Hide()
	elseif not concealed and not overlay.active then
		overlay.frame:SetBackdropColor(0,0,0,0.4)
		overlay.frame.Text:Hide()
	end

	if overlay.microadjust == 0 then
		overlay.frame.Message:Hide()
		overlay.frame.MessageBG:Hide()
		local Neuron = GetNeuron()
		if Neuron and Neuron.barEditMode then
			overlay.frame:SetFrameStrata("TOOLTIP")
		elseif Neuron then
			overlay.frame:SetFrameStrata(Neuron.STRATAS[overlay.bar:GetStrata()])
		end
	else
		-- overlay never gets keyboard events unless a high strata
		-- this hack doesn't work if there is a tooltip level bar
		-- until you choose that bar and then it starts working for others
		local Neuron = GetNeuron()
		if Neuron then
			overlay.frame:SetFrameStrata(Neuron.STRATAS[#Neuron.STRATAS])
		end
		overlay.frame:SetBackdropColor(1,1,0,0.6)
		overlay.frame.Message:Show()
		local point = overlay.bar.data.point or "CENTER"
		overlay.frame.Message:SetText(point:lower().."     x: "..format("%0.2f", overlay.bar:GetXAxis() or 0).."     y: "..format("%0.2f", overlay.bar:GetYAxis() or 0))
		overlay.frame.MessageBG:Show()
		overlay.frame.MessageBG:SetWidth(overlay.frame.Message:GetWidth()*1.05)
		overlay.frame.MessageBG:SetHeight(overlay.frame.Message:GetHeight()*1.1)
	end

	syncOverlayToBar(overlay)
	overlay.frame:SetFrameLevel((overlay.bar:GetFrameLevel() or 0) + 10)
end

---@param overlay BarOverlay
local function onEnter(overlay)
	if overlay.active then
		return
	end

	-- Hover preview only; do not mutate overlay.active (CopyTable overflows on
	-- bar/editFrame circular references).
	local concealed = overlay.bar:GetBarConceal()
	if concealed then
		overlay.frame:SetBackdropColor(1, 0, 0, 0.6)
	else
		overlay.frame:SetBackdropColor(0, 0, 1, 0.5)
	end
	overlay.frame.Text:Show()
end

---@param overlay BarOverlay
local function dragUpdate(overlay)
	if not IsMouseButtonDown("LeftButton") then
		if overlay.dragging then
			BarEditor.finishDrag(overlay)
		else
			overlay.dragPending = false
			overlay.frame:SetScript("OnUpdate", nil)
		end
		return
	end

	if overlay.dragging then
		dragBarToCursor(overlay)
		return
	end

	if overlay.dragPending then
		local cx, cy = GetCursorPosition()
		local dx = cx - overlay.dragStartX
		local dy = cy - overlay.dragStartY
		if (dx * dx + dy * dy) >= DRAG_THRESHOLD_SQ then
			overlay.dragPending = false
			overlay.dragging = true
			dragBarToCursor(overlay)
		end
	end
end

---@param overlay BarOverlay
local function beginDrag(overlay)
	if overlay.microadjust ~= 0 or overlay.dragging or overlay.dragPending then
		return
	end

	overlay.bar.data.snapToPoint = false
	overlay.bar.data.snapToFrame = false
	overlay.dragging = true
	overlay.frame:SetScript("OnUpdate", function()
		dragUpdate(overlay)
	end)
end

---@param overlay BarOverlay
---@param button string
local function armDrag(overlay, button)
	if button ~= "LeftButton" or IsShiftKeyDown() or overlay.microadjust ~= 0 then
		return
	end
	if overlay.dragging or overlay.dragPending then
		return
	end

	overlay.bar.data.snapToPoint = false
	overlay.bar.data.snapToFrame = false
	overlay.dragPending = true
	overlay.dragStartX, overlay.dragStartY = GetCursorPosition()
	overlay.frame:SetScript("OnUpdate", function()
		dragUpdate(overlay)
	end)
end

---@param overlay BarOverlay
local function finishDrag(overlay)
	stopBarDrag(overlay)

	local point

	for _,v in pairs(GetNeuron().bars) do
		if not point and overlay.bar:GetSnapTo() and v:GetSnapTo() and overlay.bar ~= v then
			point = overlay.bar:Stick(v, GetNeuron().SNAPTO_TOLERANCE, overlay.bar:GetHorizontalPad(), overlay.bar:GetVerticalPad())

			if point then
				overlay.bar.data.snapToPoint = point
				overlay.bar.data.snapToFrame = v:GetName()
				overlay.bar.data.point = "SnapTo: "..point
			end
		end
	end

	if not point then
		overlay.bar.data.snapToPoint = false
		overlay.bar.data.snapToFrame = false

		local newPoint, x, y = overlay.bar:GetPosition()
		overlay.bar.data.point = newPoint
		overlay.bar:SetXAxis(x)
		overlay.bar:SetYAxis(y)

		overlay.bar:SetPosition()
	end

	if overlay.bar:GetSnapTo() and not overlay.bar.data.snapToPoint then
		overlay.bar:StickToEdge()
	end

	overlay.bar:SetPosition()
	overlay.bar:UpdateBarStatus()
	updateAppearance(overlay)
end

---@param overlay BarOverlay
---@param button string
local function onMouseDown(overlay, button)
	armDrag(overlay, button)
end

---@param overlay BarOverlay
---@param button string
local function onDragStart(overlay, button)
	beginDrag(overlay)
end

---@param overlay BarOverlay
local function onDragStop(overlay)
	BarEditor.finishDrag(overlay)
end

---@param overlay BarOverlay
---@param key string
local function onKeyDown(overlay, key)
	if overlay.microadjust == 0 then
		return
	end
		local newPoint, x, y = overlay.bar:GetPosition()
		overlay.bar.data.point = newPoint
		overlay.bar:SetXAxis(x)
		overlay.bar:SetYAxis(y)

		overlay.bar:SetUserPlaced(false)
		overlay.bar:ClearAllPoints()

		if key == "UP" then
			overlay.bar:SetYAxis(overlay.bar:GetYAxis() + .1 * overlay.microadjust)
		elseif key == "DOWN" then
			overlay.bar:SetYAxis(overlay.bar:GetYAxis() - .1 * overlay.microadjust)
		elseif key == "LEFT" then
			overlay.bar:SetXAxis(overlay.bar:GetXAxis() - .1 * overlay.microadjust)
		elseif key == "RIGHT" then
			overlay.bar:SetXAxis(overlay.bar:GetXAxis() + .1 * overlay.microadjust)
		else
			BarEditor.microadjust(overlay, 0)
		end

		overlay.bar:SetPosition()
		overlay.bar:UpdateBarStatus()

		updateAppearance(overlay)
end


---@param overlay BarOverlay
local function onLeave(overlay)
	updateAppearance(overlay)
end

---@param overlay BarOverlay
---@param button string
---@param down boolean
local function onClick(overlay, button, down)
	overlay.onClick(overlay, button, down)
end

BarEditor = {
	---@param bar Bar
	---@param onClickCallback fun(overlay: BarOverlay, button: string, down: boolean): nil
	---@return BarOverlay
	allocate = function (bar, onClickCallback)
		---@type BarOverlay
		local overlay = {
			active = false,
			bar = bar,
			frame = -- try to pop a frame off the stack, otherwise make a new one
				table.remove(framePool) or
				createBarOverlayFrame() --[[@as NeuronBarFrame]],
			microadjust = 0,
			dragging = false,
			dragPending = false,
			onClick = onClickCallback,
		}
		overlay.frame:SetMovable(true)
		overlay.frame:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			tile = true,
			tileSize = 16,
			insets = {left = 4, right = 4, top = 4, bottom = 4}
		})

		overlay.frame.Text:SetText(bar:GetBarName())

		overlay.frame:EnableKeyboard(false)
		overlay.frame:RegisterForClicks("AnyUp", "AnyDown")
		overlay.frame:RegisterForDrag("LeftButton")
		overlay.frame:SetScript("OnMouseDown", function(_, button) onMouseDown(overlay, button) end)
		overlay.frame:SetScript("OnDragStart", function(_, button) onDragStart(overlay, button) end)
		overlay.frame:SetScript("OnDragStop", function(_) onDragStop(overlay) end)
		overlay.frame:SetScript("OnKeyDown", function(_, key) onKeyDown(overlay, key) end)
		overlay.frame:SetScript("OnEnter", function() onEnter(overlay) end)
		overlay.frame:SetScript("OnLeave", function() onLeave(overlay) end)
		overlay.frame:SetScript("OnClick", function(_, button, down) onClick(overlay, button, down) end)

		overlay.frame.Text:Show()
		overlay.frame:Show()
		updateAppearance(overlay)

		return overlay
	end,

	finishDrag = finishDrag,

	---@param overlay BarOverlay
	sync = function(overlay)
		stopBarDrag(overlay)
		updateAppearance(overlay)
	end,

	syncAll = function()
		for _, bar in pairs(GetNeuron().bars) do
			if bar.editFrame then
				stopBarDrag(bar.editFrame)
				updateAppearance(bar.editFrame)
			end
		end
	end,

	---@param overlay BarOverlay
	activate = function(overlay)
		overlay.active = true
		BarEditor.microadjust(overlay, overlay.microadjust)
		updateAppearance(overlay)
	end,

	---@param overlay BarOverlay
	deactivate = function(overlay)
		overlay.active = false
		BarEditor.microadjust(overlay, 0)

		updateAppearance(overlay)
	end,

	---@param overlay BarOverlay
	free = function (overlay)
		stopBarDrag(overlay)
		overlay.frame:SetScript("OnMouseDown", nil)
		overlay.frame:SetScript("OnDragStart", nil)
		overlay.frame:SetScript("OnDragStop", nil)
		overlay.frame:SetScript("OnUpdate", nil)
		overlay.frame:SetScript("OnEnter", nil)
		overlay.frame:SetScript("OnLeave", nil)
		overlay.frame:SetScript("OnClick", nil)
		overlay.frame:EnableKeyboard(false)
		overlay.frame:RegisterForDrag()
		overlay.frame:RegisterForClicks()
		overlay.frame:Hide()
		table.insert(framePool, overlay.frame)

		-- just for good measure to make sure nothing else can mess with
		-- the frame after we put it back into the pool
		overlay.frame = nil
	end,

	---if no value is passed in for microadjust then make it a toggle
	---@param overlay BarOverlay
	---@param microadjust number|nil
	microadjust = function(overlay, microadjust)
		if microadjust ~= nil then
			overlay.microadjust = microadjust
		elseif overlay.microadjust == 0 then
			overlay.microadjust = 1
		else
			overlay.microadjust = 0
		end

		if microadjust == 0 then
			overlay.frame:EnableKeyboard(false)
		else
			overlay.frame:EnableKeyboard(true)
		end

		updateAppearance(overlay)
	end,
}

addonTable.overlay.BarEditor = BarEditor