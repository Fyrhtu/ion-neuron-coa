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

---@return Frame @a dropdown widget
local function actionPrimaryBarKindOptions()
	local barKinds =
		Array.map(
			function(state) return state[1] end,
			Array.fromIterator(pairs(Neuron.MANAGED_HOME_STATES or {})))

	local currentKind = Array.foldl(
		function(kind, candidate)
			return Neuron.currentBar.data[candidate] and candidate or kind
		end,
		"none",
		barKinds
	)

	local kindList = Array.foldl(
		function(list, kind)
			local info = Neuron.MANAGED_HOME_STATES[kind]
			if info then
				list[kind] = info.localizedName
			end
			return list
		end,
		{ none = L["None"] },
		barKinds
	)

	local barKindDropdown = AceGUI:Create("Dropdown")
	barKindDropdown:SetLabel(L["Home State"])
	barKindDropdown:SetList(kindList)
	barKindDropdown:SetFullWidth(true)
	barKindDropdown:SetValue(currentKind)
	-- AceGUI Dropdown OnValueChanged: (widget, event, key)
	barKindDropdown:SetCallback("OnValueChanged", function(_, _, key)
		if key == "none" then
			for _, kind in ipairs(barKinds) do
				Neuron.currentBar:SetState(kind, true, false)
			end
		else
			-- Enable selected home state (SetState mutually excludes paged/stance/pet)
			Neuron.currentBar:SetState(key, true, true)
		end
	end)

	return barKindDropdown
end

---@return Frame @a group containing checkboxes
local function actionSecondaryStateOptions()
	local stateList =
		Array.map(
			function(state) return state[1] end,
			Array.fromIterator(pairs(Neuron.MANAGED_SECONDARY_STATES or {})))

	-- Rogues use stance/stealth together via the home "Stealth" stance map;
	-- the separate secondary Stealth flag is redundant and was historically hidden.
	if Neuron.class == "ROGUE" then
		stateList = Array.filter(function(state) return state ~= "stealth" end, stateList)
	end

	table.sort(stateList)

	local secondaryStatesContainer = AceGUI:Create("SimpleGroup")
	secondaryStatesContainer:SetFullWidth(true)
	secondaryStatesContainer:SetLayout("Flow")

	local heading = AceGUI:Create("Heading")
	heading:SetText(L["Secondary States"] or "Secondary States")
	heading:SetFullWidth(true)
	secondaryStatesContainer:AddChild(heading)

	for _, state in ipairs(stateList) do
		-- Lua 5.1: capture per-iteration local so OnValueChanged doesn't all
		-- bind to the final loop value (classic shared-upvalue bug).
		local stateKey = state
		local info = Neuron.MANAGED_SECONDARY_STATES[stateKey]
		if info then
			local checkbox = AceGUI:Create("CheckBox")
			checkbox:SetLabel(info.localizedName)
			checkbox:SetValue(not not Neuron.currentBar.data[stateKey])
			checkbox:SetRelativeWidth(0.33)
			checkbox:SetCallback("OnValueChanged", function(_, _, value)
				Neuron.currentBar:SetState(stateKey, true, value)
			end)
			secondaryStatesContainer:AddChild(checkbox)
		end
	end

	return secondaryStatesContainer
end

---@param tabFrame Frame
function NeuronGUI:BarStatesPanel(tabFrame)
	-- weird stuff happens if we don't wrap this in a group
	-- like dropdowns showing at the bottom of the screen and stuff
	local settingContainer = AceGUI:Create("SimpleGroup")
	settingContainer:SetFullWidth(true)
	settingContainer:SetFullHeight(true)
	settingContainer:SetLayout("List")

	settingContainer:AddChild(actionPrimaryBarKindOptions())
	settingContainer:AddChild(actionSecondaryStateOptions())

	tabFrame:AddChild(settingContainer)
end
