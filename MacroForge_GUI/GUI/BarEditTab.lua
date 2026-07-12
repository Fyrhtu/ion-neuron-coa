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

local currentTab = "general" --remember which tab we were using between refreshes
local selectedBarType --remember which bar type was selected for creating new bars between refreshes

-----------------------------------------------------------------------------
--------------------------Bar Editor-----------------------------------------
-----------------------------------------------------------------------------
function MacroForgeGUI:BarEditPanel(tabFrame)

	if not MacroForge.barEditMode then
		MacroForge:ToggleBarEditMode(true)
	else
		for _, bar in pairs(MacroForge.bars) do
			bar:PrepareForEditMode(bar == MacroForge.currentBar)
		end
	end

	-- Outer tab content uses AceGUI "Fill" which only sizes its first child.
	-- Wrap all bar-editor widgets in a single List container.
	local panel = AceGUI:Create("SimpleGroup")
	panel:SetFullWidth(true)
	panel:SetFullHeight(true)
	panel:SetLayout("List")
	tabFrame:AddChild(panel)

	-------------------------------
	--Container for the top Row
	local topRow = AceGUI:Create("SimpleGroup")
	topRow:SetFullWidth(true)
	topRow:SetHeight(50)
	topRow:SetAutoAdjustHeight(false)
	topRow:SetLayout("Flow")
	panel:AddChild(topRow)

	-------------------------------
	local spacer1 = AceGUI:Create("SimpleGroup")
	spacer1:SetWidth(20)
	spacer1:SetHeight(40)
	spacer1:SetLayout("Fill")
	topRow:AddChild(spacer1)
	-------------------------------

	local barList = {}
	for _, bar in pairs(MacroForge.bars) do
		barList[bar] = bar:GetBarName()
	end

	--Scroll frame that will contain the Bar List
	local barListDropdown = AceGUI:Create("Dropdown")
	barListDropdown:SetWidth(180)
	barListDropdown:SetLabel("Switch selected bar:")
	barListDropdown:SetText(MacroForge.currentBar and MacroForge.currentBar:GetBarName() or "")
	barListDropdown:SetList(barList) --assign the bar type table to the dropdown menu
	barListDropdown:SetCallback("OnValueChanged", function(self, callBackType, key) MacroForge.Bar.ChangeSelectedBar(key); MacroForgeGUI:RefreshEditor() end)
	topRow:AddChild(barListDropdown)

	-------------------------------
	local spacer2 = AceGUI:Create("SimpleGroup")
	spacer2:SetWidth(20)
	spacer2:SetHeight(40)
	spacer2:SetLayout("Fill")
	topRow:AddChild(spacer2)
	-------------------------------

	--populate the dropdown menu with available bar types
	local barTypes = {}
	for class, info in pairs(MacroForge.registeredBarData) do
		barTypes[class] = info.barLabel
	end

	local newBarButton

	--bar type list dropdown menu
	local barTypeDropdown = AceGUI:Create("Dropdown")
	barTypeDropdown:SetWidth(180)
	barTypeDropdown:SetLabel("Create a new bar:")
	if selectedBarType then
		barTypeDropdown:SetText(selectedBarType)
	else
		barTypeDropdown:SetText("- select a bar type -")
	end
	barTypeDropdown:SetList(barTypes) --assign the bar type table to the dropdown menu
	barTypeDropdown:SetCallback("OnValueChanged", function(self, callBackType, key) selectedBarType = key; newBarButton:SetDisabled(false) end)
	topRow:AddChild(barTypeDropdown)

	-------------------------------
	local spacer3 = AceGUI:Create("SimpleGroup")
	spacer3:SetWidth(5)
	spacer3:SetHeight(40)
	spacer3:SetLayout("Fill")
	topRow:AddChild(spacer3)
	-------------------------------

	--Create New Bar button
	newBarButton = AceGUI:Create("Button")
	newBarButton:SetWidth(120)
	newBarButton:SetText("Create")
	newBarButton:SetCallback("OnClick", function() if selectedBarType then MacroForge.Bar:CreateNewBar(selectedBarType); MacroForgeGUI:RefreshEditor() end end)
	if selectedBarType then
		newBarButton:SetDisabled(false)
	else
		newBarButton:SetDisabled(true) --we want to disable it until they chose a bar type in the dropdown
	end
	topRow:AddChild(newBarButton)


	---------------------------------
	------ Settings Tab Group -------
	---------------------------------

	if MacroForge.currentBar then
		--Tab group that will contain all of our settings to configure
		local innerTabFrame = AceGUI:Create("TabGroup")
		innerTabFrame:SetLayout("Fill")
		innerTabFrame:SetFullHeight(true)
		innerTabFrame:SetFullWidth(true)
		innerTabFrame:SetHeight(520)
		--only show the states tab if the bar is an ActionBar
		if MacroForge.currentBar.class=="ActionBar" then
			innerTabFrame:SetTabs({{text="General Configuration", value="general"}, {text="Bar States", value="states"}, {text="Bar Visibility", value="visibility"}})
		else
			innerTabFrame:SetTabs({{text="General Configuration", value="general"}, {text="Bar Visibility", value="visibility"}})
			if currentTab == "states" then
				currentTab = "general"
			end
		end
		innerTabFrame:SetCallback("OnGroupSelected", function(self, _, value) MacroForgeGUI:SelectInnerBarTab(self, _, value) end)
		panel:AddChild(innerTabFrame)

		innerTabFrame:SelectTab(currentTab)
		MacroForgeGUI:SelectInnerBarTab(innerTabFrame, nil, currentTab)
	else
		local selectBarMessage = AceGUI:Create("Label")
		selectBarMessage:SetText("Please select a bar to continue")
		selectBarMessage:SetFont("Fonts\\FRIZQT__.TTF", 30)
		panel:AddChild(selectBarMessage)
	end
end

-----------------------------------------------------------------------------
----------------------Inner Tab Frame----------------------------------------
-----------------------------------------------------------------------------

function MacroForgeGUI:SelectInnerBarTab(tabFrame, _, value)
	local registeredGUIData = MacroForge:RegisterGUI()
	tabFrame:ReleaseChildren()
	if value == "general" then
		MacroForgeGUI:GeneralConfigPanel(tabFrame, registeredGUIData)
		currentTab = "general"
	elseif value == "states" then
		MacroForgeGUI:BarStatesPanel(tabFrame)
		currentTab = "states"
	elseif value == "visibility" then
		MacroForgeGUI:BarVisibilityPanel(tabFrame)
		currentTab = "visibility"
	end
end
