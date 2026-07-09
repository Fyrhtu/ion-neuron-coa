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

-----------------------------------------------------------------------------
--------------------------Button Editor--------------------------------------
-----------------------------------------------------------------------------

local function refreshIconPreview(frame, data)
	--try to get the texture currently on the button itself
	local texture = Neuron.currentButton:GetAppearance(data)
	if texture then
		frame:SetImage(texture)
	else --fallback to question mark icon if nothing is found
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

	-- Default form (stance0) is edited via the homestate root node.
	if managed.homestate == visibilityState then
		return false
	end

	return true
end

-- States come from VISIBILITY_STATES for enabled bar modifiers, plus explicit
-- form slots when Form/Stance is the bar home state.
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
			if aStance then
				return true
			end
			if bStance then
				return false
			end
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

---@param specData GenericSpecData
---@param update fun(data: GenericSpecData): nil
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

	--container to hold all of our widgets, added to our tab frame
	local settingContainer = AceGUI:Create("SimpleGroup")
	settingContainer:SetFullWidth(true)
	settingContainer:SetLayout("Flow")


	--edit box to show the macro label
	local labelEditFrame = AceGUI:Create("EditBox")
	labelEditFrame:SetLabel("Edit Label")
	labelEditFrame:SetRelativeWidth(1)
	labelEditFrame:SetText(type(specData.macro_Text) == "string" and specData.macro_Name or "")
	labelEditFrame:DisableButton(true)
	labelEditFrame:SetCallback("OnTextChanged", function(_, _, text)
		update{macro_Name = text}
	end)
	settingContainer:AddChild(labelEditFrame)

	local mainContainer = AceGUI:Create("SimpleGroup")
	mainContainer:SetFullWidth(true)
	mainContainer:SetLayout("Flow")
	mainContainer:SetHeight(200)

	--icon button that represents the currently selected icon
	local previewIconFrame=AceGUI:Create("Icon")
	refreshIconPreview(previewIconFrame, specData)
	previewIconFrame:SetImageSize(60,60)
	previewIconFrame:SetWidth(60)
	previewIconFrame:SetCallback("OnClick", function() NeuronGUI:IconFrame_OnClick() end)
	mainContainer:AddChild(previewIconFrame)
	local updateAndRefreshIcon = function(data)
		update(data)
		refreshIconPreview(previewIconFrame, specData)
	end

	--edit box to show the current macro
	local macroEditFrame = AceGUI:Create("MultiLineEditBox")
	macroEditFrame:SetLabel("Edit Macro")
	macroEditFrame:SetWidth(420)
	macroEditFrame:SetFullHeight(true)
	macroEditFrame:SetText(type(specData.macro_Text) == "string" and specData.macro_Text or "")
	macroEditFrame:DisableButton(true)
	macroEditFrame:SetCallback("OnTextChanged", function(_, _, text)
		local updates = { macro_Text = text }
		-- Clearing macro text manually must drop linked Blizzard macro / equipset
		-- metadata or UPDATE_MACROS can repopulate the button and block drag auto-write.
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

	-- Only build spec trees that matter. Previously specs[5] ("No Spec") was
	-- always appended; with multi-spec off, Fill layout still created a second
	-- TreeGroup whose scrollbar leaked through as a stray up-arrow below the tree.
	-- On Ascension CoA, Spec.names() already lists Character Advancement specs
	-- (up to 20) — do not append a fake retail "No Spec" slot.
	local specList = {}
	if multiSpec then
		local specs = Spec.names(multiSpec)
		for specIndex, specName in ipairs(specs) do
			specList[#specList + 1] = { specIndex, specName }
		end
		if not (Spec.isAscension and Spec.isAscension()) then
			specList[#specList + 1] = { 5, L["No Spec"] }
		end
	else
		specList[1] = { 1, "" }
	end

	for _, specEntry in ipairs(specList) do
		local specIndex, specName = specEntry[1], specEntry[2]
		local specData = select(1, Neuron:EnsureButtonSpecData(Neuron.currentButton.DB, specIndex, "homestate"))

		local rootLabel = getHomeStateLabel()
		if specName and specName ~= "" then
			rootLabel = specName .. " (" .. rootLabel .. ")"
		else
			rootLabel = "(" .. rootLabel .. ")"
		end

		local buttonTree = {
			value = "homestate",
			text = rootLabel,
			children = Array.map(
				function(state)
					return {
						value = state,
						text = Neuron.STATES[state] or state,
					}
				end,
				getStateList()
			),
		}

		local specButtonTree = AceGUI:Create("TreeGroup")
		specButtonTree:SetFullWidth(true)
		specButtonTree:SetFullHeight(true)
		specButtonTree:SetLayout("Fill")
		if specButtonTree.SetTreeWidth then
			specButtonTree:SetTreeWidth(220)
		end
		if specButtonTree.EnableButtonTooltips then
			specButtonTree:EnableButtonTooltips(false)
		end
		specButtonTree:SetTree({buttonTree})
		specButtonTree:SetCallback("OnGroupSelected", function(container, _, joinedState)
			container:ReleaseChildren()

			local splitState = {}
			for part in string.gmatch(joinedState, "[^\001]+") do
				splitState[#splitState + 1] = part
			end
			if #splitState == 0 then
				splitState[1] = joinedState
			end
			local state = splitState[#splitState] or "homestate"

			local _, stateData = Neuron:EnsureButtonSpecData(Neuron.currentButton.DB, specIndex, state)
			local buttonEditor = buttonEditPanel(stateData, function(data)
				for k,v in pairs(data) do
					stateData[k] = v
				end

				if Spec.active(multiSpec) ~= specIndex then
					-- don't update the button if the modified spec isn't active
					return
				end

				-- for some reason we need to do a full bar load or the buttons don't
				-- update. we can investigate further, but note that switching specs
				-- probably needs the same fix
				Neuron.currentButton.bar:Load()
				--Neuron.currentButton:LoadDataFromDatabase(specIndex, state)
				--Neuron.currentButton:UpdateAll()
			end)
			container:AddChild(buttonEditor)
		end)

		specButtonTree:SelectByValue("homestate")

		topContainer:AddChild(specButtonTree)
	end
end
