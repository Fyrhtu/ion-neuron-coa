-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local Neuron = addonTable.Neuron

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local Array = addonTable.utilities.Array

-- this function takes a partial bar config and fills out the missing fields
-- from the database default skeleton to create a complete bar database entry
local function initializeBar(barClass)
	return function (bar)
		-- MergeTable modifies in place, so copy  the default first
		local newBar = CopyTable(addonTable.databaseDefaults.profile[barClass]['*'])

		-- use the skeleton button from the default database to generate buttons
		local newButtons = Array.map(
			function(button)
				local newButton = CopyTable(newBar.buttons['*'])
				local newConfig = CopyTable(newButton.config)

				MergeTable(newConfig, button.config or {})
				MergeTable(newButton, button)
				MergeTable(newButton, {config = newConfig})
				return newButton
			end,
			bar.buttons
		)

		-- merge the bar config and then the buttons into the skeleton
		MergeTable(newBar, bar)
		MergeTable(newBar, {buttons=newButtons})
		return newBar
	end
end

--- Ensure per-spec / per-state macro data exists on an action button DB entry.
function Neuron:EnsureButtonSpecData(buttonDB, specIndex, state)
	if type(buttonDB) ~= "table" then
		return { homestate = {} }, {}
	end

	specIndex = specIndex or 1
	state = state or "homestate"

	local specData = rawget(buttonDB, specIndex)
	if type(specData) ~= "table" then
		specData = { homestate = {} }
		rawset(buttonDB, specIndex, specData)
	end

	if type(specData[state]) ~= "table" then
		specData[state] = {
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

	return specData, specData[state]
end

--- Button skeleton lives under profile[barClass]['*'].buttons['*'], not profile[barClass].buttons.
function Neuron:GetButtonSkeleton(barClass)
	local barDefaults = addonTable.databaseDefaults.profile[barClass]
	local barSkeleton = barDefaults and barDefaults['*']
	return barSkeleton and barSkeleton.buttons and barSkeleton.buttons['*']
end

--- Fill missing button config keys from the database skeleton (e.g. cast bar width/height).
function Neuron:MergeButtonConfigDefaults(barClass, config)
	local buttonSkeleton = Neuron:GetButtonSkeleton(barClass)
	local defaults = buttonSkeleton and buttonSkeleton.config
	if not defaults then
		return config or {}
	end

	config = config or {}
	for k, v in pairs(defaults) do
		if config[k] == nil then
			if type(v) == "table" then
				config[k] = CopyTable(v)
			else
				config[k] = v
			end
		end
	end
	return config
end

--- Create a fresh button database entry without AceDB __index side effects.
function Neuron:CreateButtonDatabaseEntry(barClass)
	local buttonSkeleton = Neuron:GetButtonSkeleton(barClass)

	if not buttonSkeleton then
		return {
			config = { btnType = "macro" },
			keys = { hotKeyLock = false, hotKeyPri = false, hotKeys = ":" },
			data = {},
		}
	end

	local entry = CopyTable(buttonSkeleton)
	entry['*'] = nil
	entry['**'] = nil

	if barClass == "ActionBar" then
		for specIndex = 1, 5 do
			if type(entry[specIndex]) ~= "table" then
				entry[specIndex] = { homestate = {} }
			elseif type(entry[specIndex].homestate) ~= "table" then
				entry[specIndex].homestate = {}
			end
			entry[specIndex]['*'] = nil
			entry[specIndex]['**'] = nil
		end
	elseif type(entry.data) ~= "table" then
		entry.data = {}
	end

	return entry
end

--- Create a fresh bar database entry without triggering AceDB __index side effects.
function Neuron:CreateBarDatabaseEntry(barClass)
	local skeleton = addonTable.databaseDefaults.profile[barClass]
		and addonTable.databaseDefaults.profile[barClass]['*']
	if not skeleton then
		return { buttons = {}, hidestates = ":" }
	end

	local entry = CopyTable(skeleton)
	entry.buttons = {}
	if barClass == "ActionBar" then
		entry.buttons[1] = Neuron:CreateButtonDatabaseEntry(barClass)
	end
	return entry
end

--- this function has no business existing
--- database defaults should be in the database
--- but we have them scattered between neuron-defaults and neuron-db-defaults
function Neuron:InitializeEmptyDatabase(DB)
	DB.firstRun = false

	--initialize default bars using the skeleton data in defaultProfile
	--and pulling from registeredBarData so we create the correct bars for classic/retail
	for barClass, registeredData in pairs(Neuron.registeredBarData) do
		local newBars = Array.map(
			initializeBar(barClass),
			addonTable.defaultProfile[barClass]
		)
		MergeTable(registeredData.barDB, newBars)
	end
end

function Neuron:CreateBarsAndButtons(profileData)
	-- remove blizzard controlled bars from the list of bars we will create
	-- but still keep neuron action bars regardless
	local neuronBars =
		Array.filter(
			function (barPair)
				local bar, _ = unpack(barPair)
			  return not profileData.blizzBars[bar] or bar == "ActionBar"
			end,
		Array.fromIterator(pairs(Neuron.registeredBarData)))

	-- make the frames for the bars now
	for _, barData in pairs (neuronBars) do
		local barClass, barClassData = unpack(barData)
		for id,data in pairs(barClassData.barDB) do
			if data ~= nil then
				local newBar = Neuron.Bar.new(barClass, id) --this calls the bar constructor

				--create all the saved button objects for a given bar
				local buttonIDs = {}
				for buttonID in pairs(newBar.data.buttons or {}) do
					if type(buttonID) == "number" then
						table.insert(buttonIDs, buttonID)
					end
				end
				table.sort(buttonIDs)
				for _, buttonID in ipairs(buttonIDs) do
					newBar.objTemplate.new(newBar, buttonID)
				end
				newBar:EnsureMinimumButtons()
			end
		end
	end
end
