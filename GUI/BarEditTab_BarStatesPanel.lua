-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local Neuron = addonTable.Neuron

local NeuronGUI = Neuron.NeuronGUI

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local AceGUI = LibStub("AceGUI-3.0")
local Array = addonTable.utilities.Array

local function currentHomeStateKey()
	local barData = Neuron.currentBar.data
	for _, kind in ipairs(Neuron:GetHomeStateKeys()) do
		if barData[kind] then
			return kind
		end
	end
	return "none"
end

---@return Frame @a dropdown widget
local function actionPrimaryBarKindOptions()
	local kindList = { none = L["None"] }
	for _, kind in ipairs(Neuron:GetHomeStateKeys()) do
		local info = Neuron.MANAGED_HOME_STATES and Neuron.MANAGED_HOME_STATES[kind]
		if info then
			kindList[kind] = info.localizedName
		end
	end

	local barKindDropdown = AceGUI:Create("Dropdown")
	barKindDropdown:SetLabel(L["Home State"])
	barKindDropdown:SetList(kindList)
	barKindDropdown:SetFullWidth(true)
	barKindDropdown:SetValue(currentHomeStateKey())
	barKindDropdown:SetCallback("OnValueChanged", function(widget)
		Neuron.currentBar:SetHomeState(widget:GetValue())
	end)

	return barKindDropdown
end

---@return Frame @a group containing checkboxes
local function actionSecondaryStateOptions()
	local stateList =
		Array.map(
			function(state) return state[1] end,
			Array.fromIterator(pairs(Neuron.MANAGED_SECONDARY_STATES or {})))

	if Neuron.class == "ROGUE" then
		stateList = Array.filter(function(state) return state ~= "stealth" end, stateList)
	end

	local secondaryStatesContainer = AceGUI:Create("SimpleGroup")
	secondaryStatesContainer:SetFullWidth(true)
	secondaryStatesContainer:SetLayout("Flow")

	local heading = AceGUI:Create("Heading")
	heading:SetText("Secondary States")
	heading:SetFullWidth(true)
	secondaryStatesContainer:AddChild(heading)

	for _, state in ipairs(stateList) do
		local info = Neuron.MANAGED_SECONDARY_STATES[state]
		if info then
			local checkbox = AceGUI:Create("CheckBox")
			checkbox:SetLabel(info.localizedName)
			checkbox:SetValue(not not Neuron.currentBar.data[state])
			checkbox:SetRelativeWidth(0.33)
			checkbox:SetCallback("OnValueChanged", function(widget)
				Neuron.currentBar:SetState(state, true, widget:GetValue())
			end)
			secondaryStatesContainer:AddChild(checkbox)
		end
	end

	return secondaryStatesContainer
end

---@param tabFrame Frame
function NeuronGUI:BarStatesPanel(tabFrame)
	local settingContainer = AceGUI:Create("SimpleGroup")
	settingContainer:SetFullWidth(true)
	settingContainer:SetFullHeight(true)
	settingContainer:SetLayout("List")

	settingContainer:AddChild(actionPrimaryBarKindOptions())
	settingContainer:AddChild(actionSecondaryStateOptions())

	tabFrame:AddChild(settingContainer)
end
