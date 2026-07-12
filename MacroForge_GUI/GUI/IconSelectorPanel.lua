-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local MacroForge = LibStub("AceAddon-3.0"):GetAddon("MacroForge")
local addonTable = MacroForge.package
-- was: local _, addonTable = ...

local MacroForgeGUI = MacroForge.MacroForgeGUI

local L = LibStub("AceLocale-3.0"):GetLocale("MacroForge")
local AceGUI = LibStub("AceGUI-3.0")

local iconSelector
local iconList = {}

local MAX_ICONS_PER_PAGE = 120
local ICON_SCROLL_HEIGHT = 400
local curIconPage = 1

-----------------------------------------------------------------------------
--------------------------Icon Selector--------------------------------------
-----------------------------------------------------------------------------

local function addUniqueIcon(seen, texture)
	if type(texture) ~= "string" or texture == "" then
		return
	end
	if seen[texture] then
		return
	end
	seen[texture] = true
	iconList[#iconList + 1] = texture
end

local function addSpellbookIcons(seen)
	local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
	local indexMax = 0

	for tab = 1, numTabs do
		local _, _, _, numSlots = GetSpellTabInfo(tab)
		indexMax = indexMax + (numSlots or 0)
	end

	for index = 1, indexMax do
		local _, spellID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
		if spellID then
			local texture = GetSpellTexture(spellID)
			addUniqueIcon(seen, texture)
		end
	end
end

function MacroForgeGUI:GenerateIconList()
	wipe(iconList)
	local seen = {}

	if MacroForge.UpdateSpellCache then
		MacroForge:UpdateSpellCache()
	end

	for _, v in pairs(MacroForge.spellCache or {}) do
		addUniqueIcon(seen, v.icon)
		addUniqueIcon(seen, v.altIcon)
	end

	for _, v in pairs(MacroForge.itemCache or {}) do
		if type(v) == "number" then
			local texture = GetItemIcon(v)
			addUniqueIcon(seen, texture)
		elseif type(v) == "table" then
			addUniqueIcon(seen, v.icon)
		end
	end

	if type(GetNumMacroIcons) == "function" and type(GetMacroIconInfo) == "function" then
		for i = 1, GetNumMacroIcons() do
			addUniqueIcon(seen, GetMacroIconInfo(i))
		end
	end

	if type(GetNumMacroItemIcons) == "function" and type(GetMacroItemIconInfo) == "function" then
		for i = 1, GetNumMacroItemIcons() do
			addUniqueIcon(seen, GetMacroItemIconInfo(i))
		end
	end

	if type(GetLooseMacroIcons) == "function" then
		GetLooseMacroIcons(iconList)
		for _, texture in ipairs(iconList) do
			seen[texture] = true
		end
	end
	if type(GetLooseMacroItemIcons) == "function" then
		GetLooseMacroItemIcons(iconList)
		for _, texture in ipairs(iconList) do
			seen[texture] = true
		end
	end
	if type(GetMacroIcons) == "function" then
		GetMacroIcons(iconList)
		for _, texture in ipairs(iconList) do
			seen[texture] = true
		end
	end
	if type(GetMacroItemIcons) == "function" then
		GetMacroItemIcons(iconList)
		for _, texture in ipairs(iconList) do
			seen[texture] = true
		end
	end

	if #iconList == 0 then
		addSpellbookIcons(seen)
	end

	table.sort(iconList)
end

function MacroForgeGUI:IconFrame_OnClick()
	MacroForgeGUI:CreateIconSelector()
end

function MacroForgeGUI:CreateIconSelector()
	if iconSelector then
		AceGUI:Release(iconSelector)
		iconSelector = nil
	end

	curIconPage = 1
	MacroForgeGUI:GenerateIconList()

	iconSelector = AceGUI:Create("Frame")
	iconSelector:SetTitle("Select an icon")
	iconSelector:SetCallback("OnClose", function()
		if iconSelector then
			AceGUI:Release(iconSelector)
			iconSelector = nil
		end
	end)
	iconSelector:SetWidth(610)
	iconSelector:SetHeight(500)
	iconSelector:EnableResize(true)
	if iconSelector.frame.SetResizeBounds then
		iconSelector.frame:SetResizeBounds(610, 450)
	else
		iconSelector.frame:SetMinResize(610, 450)
	end
	iconSelector:SetLayout("List")

	MacroForgeGUI:CreateIconSelectorInternals()
end

function MacroForgeGUI:RefreshIconSelector()
	if not iconSelector then
		return
	end
	MacroForgeGUI:GenerateIconList()
	iconSelector:ReleaseChildren()
	MacroForgeGUI:CreateIconSelectorInternals()
end

function MacroForgeGUI:CreateIconSelectorInternals()
	if not iconSelector then
		return
	end

	local totalPages = math.max(1, math.ceil(#iconList / MAX_ICONS_PER_PAGE))
	curIconPage = math.min(math.max(curIconPage, 1), totalPages)

	local paginationContainer = AceGUI:Create("SimpleGroup")
	paginationContainer:SetLayout("Flow")
	paginationContainer:SetFullWidth(true)
	paginationContainer:SetHeight(70)
	iconSelector:AddChild(paginationContainer)

	local backButton = AceGUI:Create("Button")
	backButton:SetRelativeWidth(0.15)
	backButton:SetText("Previous")
	backButton:SetDisabled(curIconPage <= 1)
	backButton:SetCallback("OnClick", function()
		if curIconPage > 1 then
			curIconPage = curIconPage - 1
			MacroForgeGUI:RefreshIconSelector()
		end
	end)
	paginationContainer:AddChild(backButton)

	local paginationSlider = AceGUI:Create("Slider")
	paginationSlider:SetRelativeWidth(0.68)
	paginationSlider:SetSliderValues(1, totalPages, 1)
	paginationSlider:SetLabel("Page")
	paginationSlider:SetValue(curIconPage)
	paginationSlider:SetCallback("OnValueChanged", function(widget)
		curIconPage = widget:GetValue()
		MacroForgeGUI:RefreshIconSelector()
	end)
	paginationContainer:AddChild(paginationSlider)

	local forwardButton = AceGUI:Create("Button")
	forwardButton:SetRelativeWidth(0.15)
	forwardButton:SetText("Next")
	forwardButton:SetDisabled(curIconPage >= totalPages)
	forwardButton:SetCallback("OnClick", function()
		if curIconPage < totalPages then
			curIconPage = curIconPage + 1
			MacroForgeGUI:RefreshIconSelector()
		end
	end)
	paginationContainer:AddChild(forwardButton)

	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetLayout("Fill")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetHeight(ICON_SCROLL_HEIGHT)
	iconSelector:AddChild(scrollContainer)

	local iconScroll = AceGUI:Create("ScrollFrame")
	iconScroll:SetLayout("Flow")
	scrollContainer:AddChild(iconScroll)

	if #iconList == 0 then
		local emptyLabel = AceGUI:Create("Label")
		emptyLabel:SetFullWidth(true)
		emptyLabel:SetText("No icons available. Open your spellbook or drag abilities to your bars, then reopen this picker.")
		iconScroll:AddChild(emptyLabel)
		return
	end

	local start = ((curIconPage - 1) * MAX_ICONS_PER_PAGE) + 1
	local stop = math.min(curIconPage * MAX_ICONS_PER_PAGE, #iconList)

	for i = start, stop do
		local texture = iconList[i]
		if texture then
			local iconFrame = AceGUI:Create("Icon")
			iconFrame:SetImage(texture)
			iconFrame:SetImageSize(40, 40)
			iconFrame:SetWidth(50)
			iconFrame:SetCallback("OnClick", function()
				if MacroForge.currentButton then
					MacroForge.currentButton:SetMacroIcon(texture)
					MacroForge.currentButton:UpdateIcon()
				end
				if iconSelector then
					AceGUI:Release(iconSelector)
					iconSelector = nil
				end
				MacroForgeGUI:RefreshEditor("button")
			end)
			iconScroll:AddChild(iconFrame)
		end
	end
end
