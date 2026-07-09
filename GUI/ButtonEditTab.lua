-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local Neuron = addonTable.Neuron

local NeuronGUI = Neuron.NeuronGUI

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local AceGUI = LibStub("AceGUI-3.0")

local Spec = addonTable.utilities.Spec
local Array = addonTable.utilities.Array

local TREE_SEP = "\001"

-----------------------------------------------------------------------------
--------------------------Button Editor--------------------------------------
-----------------------------------------------------------------------------

local function refreshIconPreview(frame, data)
	local texture = Neuron.currentButton:GetAppearance(data)
	if texture then
		frame:SetImage(texture)
	else
		frame:SetImage("INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK")
	end
end

local function visibilityMatchesBarState(barState, visibilityState)
	local managed = Neuron.MANAGED_BAR_STATES[barState]
	if not managed or not managed.states then
		return false
	end
	if not managed.states:find(visibilityState, 1, true) then
		return false
	end
	if managed.homestate == visibilityState then
		return false
	end
	return true
end

local function getStateList()
	local barData = Neuron.currentButton.bar.data

	local barStates =
		Array.filter(function(state) return barData[state] end,
		Array.map(function(state) return state[1] end,
		Array.fromIterator(pairs(Neuron.MANAGED_BAR_STATES))))

	local visibilityStates =
		Array.filter(
			function(visibilityState)
				return Array.find(
					function(barState)
						return visibilityMatchesBarState(barState, visibilityState)
					end,
					barStates
				)
			end,
		Array.map(function(state) return state[1] end,
		Array.fromIterator(pairs(Neuron.VISIBILITY_STATES))))

	if barData.stance then
		local seen = {}
		for _, state in ipairs(visibilityStates) do
			seen[state] = true
		end
		local stanceInfo = Neuron.MANAGED_BAR_STATES.stance
		local rangeStop = stanceInfo and stanceInfo.rangeStop or 8
		for slot = 1, rangeStop do
			local stateKey = "stance" .. slot
			if not seen[stateKey] and Neuron.STATES[stateKey] then
				visibilityStates[#visibilityStates + 1] = stateKey
				seen[stateKey] = true
			end
		end
		table.sort(visibilityStates, function(a, b)
			local aStance = a:match("^stance(%d+)$")
			local bStance = b:match("^stance(%d+)$")
			if aStance and bStance then
				return tonumber(aStance) < tonumber(bStance)
			end
			if aStance then return true end
			if bStance then return false end
			return a < b
		end)
	end

	return visibilityStates
end

local function getHomeStateLabel()
	if Neuron.currentButton.bar.data.stance then
		local homestate = Neuron.MANAGED_BAR_STATES.stance and Neuron.MANAGED_BAR_STATES.stance.homestate
		if homestate and Neuron.STATES[homestate] then
			return Neuron.STATES[homestate]
		end
	end
	return Neuron.STATES.homestate
end

--- Parse AceGUI TreeGroup unique value into spec index + bar state.
local function parseTreeSelection(joinedState, multiSpec)
	local parts = {}
	for part in string.gmatch(joinedState or "", "[^" .. TREE_SEP .. "]+") do
		parts[#parts + 1] = part
	end
	if multiSpec then
		local specIndex = tonumber(parts[1]) or Spec.active(true) or 1
		local state = parts[2] or "homestate"
		return specIndex, state
	end
	return 1, (parts[#parts] or parts[1] or "homestate")
end

---@param specData table
---@param update fun(data: table): nil
---@return Frame
local function buttonEditPanel(specData, update)
	if not specData then
		specData = {
			actionID = false,
			macro_Text = "",
			macro_Icon = false,
			macro_Name = "",
			macro_Note = "",
			macro_UseNote = false,
			macro_BlizzMacro = false,
			macro_EquipmentSet = false,
		}
	end

	local settingContainer = AceGUI:Create("SimpleGroup")
	settingContainer:SetFullWidth(true)
	settingContainer:SetLayout("Flow")

	local labelEditFrame = AceGUI:Create("EditBox")
	labelEditFrame:SetLabel("Edit Label")
	labelEditFrame:SetRelativeWidth(1)
	labelEditFrame:SetText(type(specData.macro_Name) == "string" and specData.macro_Name or "")
	labelEditFrame:DisableButton(true)
	labelEditFrame:SetCallback("OnTextChanged", function(_, _, text)
		update{macro_Name = text}
	end)
	settingContainer:AddChild(labelEditFrame)

	local mainContainer = AceGUI:Create("SimpleGroup")
	mainContainer:SetFullWidth(true)
	mainContainer:SetLayout("Flow")
	mainContainer:SetHeight(200)

	local previewIconFrame = AceGUI:Create("Icon")
	refreshIconPreview(previewIconFrame, specData)
	previewIconFrame:SetImageSize(60, 60)
	previewIconFrame:SetWidth(60)
	previewIconFrame:SetCallback("OnClick", function() NeuronGUI:IconFrame_OnClick() end)
	mainContainer:AddChild(previewIconFrame)

	local updateAndRefreshIcon = function(data)
		update(data)
		refreshIconPreview(previewIconFrame, specData)
	end

	local macroEditFrame = AceGUI:Create("MultiLineEditBox")
	macroEditFrame:SetLabel("Edit Macro")
	macroEditFrame:SetWidth(420)
	macroEditFrame:SetFullHeight(true)
	macroEditFrame:SetText(type(specData.macro_Text) == "string" and specData.macro_Text or "")
	macroEditFrame:DisableButton(true)
	macroEditFrame:SetCallback("OnTextChanged", function(_, _, text)
		local updates = { macro_Text = text }
		if type(text) ~= "string" or not text:match("%S") then
			updates.macro_BlizzMacro = false
			updates.macro_EquipmentSet = false
		end
		updateAndRefreshIcon(updates)
	end)
	mainContainer:AddChild(macroEditFrame)
	settingContainer:AddChild(mainContainer)

	local buttonContainer = AceGUI:Create("SimpleGroup")
	buttonContainer:SetFullWidth(true)
	buttonContainer:SetLayout("Flow")

	local clearButton = AceGUI:Create("Button")
	clearButton:SetText(L["Clear Button"])
	clearButton:SetCallback("OnClick", function()
		local reset = CopyTable(Neuron.ActionButton.EMPTY_STATE_DATA)
		update(reset)
		labelEditFrame:SetText("")
		macroEditFrame:SetText("")
		refreshIconPreview(previewIconFrame, specData)
	end)
	buttonContainer:AddChild(clearButton)

	local resetIconButton = AceGUI:Create("Button")
	resetIconButton:SetText(L["Reset Icon"])
	resetIconButton:SetCallback("OnClick", function()
		updateAndRefreshIcon{macro_Icon = false}
	end)
	buttonContainer:AddChild(resetIconButton)

	settingContainer:AddChild(buttonContainer)
	return settingContainer
end

function NeuronGUI:ButtonsEditPanel(topContainer)
	Neuron:ToggleButtonEditMode(true)

	if not Neuron.currentButton then
		return
	end

	local multiSpec = Neuron.currentButton.bar:GetMultiSpec()
	local activeSpec = Spec.active(true) or 1

	-- ONE TreeGroup:
	--   multi-spec ON  -> Spec nodes as roots, form/state children
	--   multi-spec OFF -> single home-state root
	-- Multiple TreeGroups under Fill layout only showed Spec 1 and looked
	-- like talent specs "vanished" when Spec.names() was empty.
	local treeNodes = {}
	local defaultSelect

	if multiSpec then
		local specs = Spec.names(true)
		if type(specs) ~= "table" or #specs < 1 then
			specs = { (L["Specialization"] or "Spec") .. " 1" }
		end

		for specIndex, specName in ipairs(specs) do
			Neuron:EnsureButtonSpecData(Neuron.currentButton.DB, specIndex, "homestate")

			local label = specName
			if not label or label == "" then
				label = (L["Specialization"] or "Spec") .. " " .. specIndex
			end
			if specIndex == activeSpec then
				label = label .. "  [" .. (L["Active"] or "Active") .. "]"
			end

			local children = {
				{ value = "homestate", text = getHomeStateLabel() },
			}
			for _, state in ipairs(getStateList()) do
				children[#children + 1] = {
					value = state,
					text = Neuron.STATES[state] or state,
				}
			end

			treeNodes[#treeNodes + 1] = {
				value = tostring(specIndex),
				text = label,
				children = children,
			}
		end

		if not (Spec.isAscension and Spec.isAscension()) then
			treeNodes[#treeNodes + 1] = {
				value = "5",
				text = L["No Spec"],
				children = {
					{ value = "homestate", text = getHomeStateLabel() },
				},
			}
		end

		defaultSelect = tostring(activeSpec) .. TREE_SEP .. "homestate"
	else
		Neuron:EnsureButtonSpecData(Neuron.currentButton.DB, 1, "homestate")
		local children = Array.map(
			function(state)
				return { value = state, text = Neuron.STATES[state] or state }
			end,
			getStateList()
		)
		treeNodes[1] = {
			value = "homestate",
			text = "(" .. getHomeStateLabel() .. ")",
			children = children,
		}
		defaultSelect = "homestate"
	end

	local specButtonTree = AceGUI:Create("TreeGroup")
	specButtonTree:SetFullWidth(true)
	specButtonTree:SetFullHeight(true)
	specButtonTree:SetLayout("Fill")
	if specButtonTree.SetTreeWidth then
		specButtonTree:SetTreeWidth(240)
	end
	if specButtonTree.EnableButtonTooltips then
		specButtonTree:EnableButtonTooltips(false)
	end
	specButtonTree:SetTree(treeNodes)

	specButtonTree:SetCallback("OnGroupSelected", function(container, _, joinedState)
		container:ReleaseChildren()

		local specIndex, state = parseTreeSelection(joinedState, multiSpec)
		local _, stateData = Neuron:EnsureButtonSpecData(Neuron.currentButton.DB, specIndex, state)

		NeuronGUI.editingSpecIndex = specIndex
		NeuronGUI.editingState = state
		NeuronGUI.editingStateData = stateData

		local buttonEditor = buttonEditPanel(stateData, function(data)
			for k, v in pairs(data) do
				stateData[k] = v
			end
			if Spec.active(multiSpec) ~= specIndex then
				return
			end
			if not InCombatLockdown() then
				Neuron.currentButton:LoadDataFromDatabase(specIndex, state)
				if Neuron.currentButton.UpdateButtonSpec then
					Neuron.currentButton:UpdateButtonSpec(specIndex)
				else
					Neuron.currentButton.bar:Load()
				end
			end
		end)
		container:AddChild(buttonEditor)
	end)

	specButtonTree:SelectByValue(defaultSelect)
	if multiSpec and not NeuronGUI.editingStateData then
		specButtonTree:SelectByValue(tostring(activeSpec))
		specButtonTree:SelectByValue(defaultSelect)
	end

	topContainer:AddChild(specButtonTree)
end
