-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
addonTable.utilities = addonTable.utilities or {}

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local Array = addonTable.utilities.Array

-- Neuron button DB only ever used 1-5 (retail/wotlk dual talent + "no spec").
-- Ascension CoA exposes up to 20 character specializations via SpecializationUtil.
local ASCENSION_MAX_SPECS = 20

local wrathSpecNames = {
	TALENT_SPEC_PRIMARY or "Primary",
	TALENT_SPEC_SECONDARY or "Secondary",
}

---------------------------------------------------------------------------
-- Capability detection
---------------------------------------------------------------------------

--- Project Ascension / CoA multi-specialization API (up to 20 saved specs).
local function hasAscensionSpecAPI()
	return type(SpecializationUtil) == "table"
		and type(SpecializationUtil.GetActiveSpecialization) == "function"
		and type(SpecializationUtil.GetNumSpecializations) == "function"
end

--- Retail Blizzard specialization APIs (not present on Ascension 3.3.5 base).
local function hasRetailSpecAPI()
	return type(GetSpecialization) == "function"
		and type(GetSpecializationInfo) == "function"
		and type(GetNumSpecializations) == "function"
		and type(GetNumSpecializationsForClassID) == "function"
end

---------------------------------------------------------------------------
-- Ascension CoA: SpecializationUtil
---------------------------------------------------------------------------

local function getAscensionActive()
	local ok, index = pcall(SpecializationUtil.GetActiveSpecialization)
	if not ok or index == nil then
		return nil, nil
	end
	index = tonumber(index)
	if not index or index < 1 then
		return nil, nil
	end

	local name
	if type(SpecializationUtil.GetSpecializationInfo) == "function" then
		local okName, info = pcall(SpecializationUtil.GetSpecializationInfo, index)
		if okName then
			-- API may return name as first value, or (id, name, ...)
			if type(info) == "string" then
				name = info
			elseif type(info) == "number" then
				local ok2, n2 = pcall(function()
					return select(2, SpecializationUtil.GetSpecializationInfo(index))
				end)
				if ok2 and type(n2) == "string" then
					name = n2
				end
			end
		end
	end

	return index, name or (L["Specialization"] and (L["Specialization"] .. " " .. index) or ("Spec " .. index))
end

local function getAscensionCount()
	local ok, num = pcall(SpecializationUtil.GetNumSpecializations)
	if ok and type(num) == "number" and num >= 1 then
		-- Cap to what we will store in the button DB
		if num > ASCENSION_MAX_SPECS then
			return ASCENSION_MAX_SPECS
		end
		return num
	end
	return 1
end

local function getAscensionNames()
	local count = getAscensionCount()
	local names = {}
	for i = 1, count do
		local name
		if type(SpecializationUtil.GetSpecializationInfo) == "function" then
			local ok, info = pcall(SpecializationUtil.GetSpecializationInfo, i)
			if ok then
				if type(info) == "string" and info ~= "" then
					name = info
				else
					local ok2, n2 = pcall(function()
						return select(2, SpecializationUtil.GetSpecializationInfo(i))
					end)
					if ok2 and type(n2) == "string" and n2 ~= "" then
						name = n2
					end
				end
			end
		end
		names[i] = name or ("Spec " .. i)
	end
	return names
end

---------------------------------------------------------------------------
-- WotLK dual talent / retail fallbacks
---------------------------------------------------------------------------

local function getActiveTalentGroupIndex()
	if type(GetActiveTalentGroup) ~= "function" then
		return nil
	end

	local ok, index = pcall(GetActiveTalentGroup, false, false)
	if ok and type(index) == "number" and index >= 1 then
		return index
	end

	ok, index = pcall(GetActiveTalentGroup)
	if ok and type(index) == "number" and index >= 1 then
		return index
	end

	return nil
end

local function getNumTalentGroups()
	if type(GetNumTalentGroups) ~= "function" then
		return 2
	end

	local ok, num = pcall(GetNumTalentGroups, false, false)
	if ok and type(num) == "number" and num >= 1 then
		return num
	end

	ok, num = pcall(GetNumTalentGroups)
	if ok and type(num) == "number" and num >= 1 then
		return num
	end

	return 2
end

local function getRetailSpecIndex()
	local index = GetSpecialization()
	if type(index) ~= "number" or index < 1 then
		return 1, ""
	end
	if index > 4 and (not GetSpecializationInfo(index) or select(2, GetSpecializationInfo(index)) == nil) then
		return 5, L["No Spec"] or "No Spec"
	end
	local _, name = GetSpecializationInfo(index)
	return index, name or ""
end

---------------------------------------------------------------------------
-- Public Spec API used by bars / button editor
---------------------------------------------------------------------------

local Spec; Spec = {
	--- True when Project Ascension multi-specialization APIs are present.
	isAscension = function()
		return hasAscensionSpecAPI()
	end,

	--- Max specialization slots Neuron will store for this client.
	maxSlots = function()
		if hasAscensionSpecAPI() then
			return ASCENSION_MAX_SPECS
		end
		if hasRetailSpecAPI() then
			return 5
		end
		return getNumTalentGroups()
	end,

	--- Currently active specialization index + display name.
	-- @param multiSpec boolean when false, always report index 1 (shared layout)
	active = function(multiSpec)
		local index, name

		-- Ascension CoA first: Character Advancement specializations (up to 20).
		if hasAscensionSpecAPI() then
			index, name = getAscensionActive()
			if not index then
				index, name = 1, ""
			end
		elseif hasRetailSpecAPI() then
			index, name = getRetailSpecIndex()
		else
			index = getActiveTalentGroupIndex() or 1
			local numGroups = getNumTalentGroups()
			if index > numGroups then
				index = 1
			end
			name = wrathSpecNames[index] or ("Talent Set " .. tostring(index))
		end

		if not multiSpec then
			index = 1
		end

		return index, name or ""
	end,

	--- Ordered list of specialization names for the button editor tabs.
	names = function(multiSpec)
		local names

		if hasAscensionSpecAPI() then
			names = getAscensionNames()
		elseif hasRetailSpecAPI() then
			names = Array.initialize(
				GetNumSpecializations(),
				function(i) return select(2, GetSpecializationInfo(i)) or ("Spec " .. i) end
			)
		else
			local numGroups = getNumTalentGroups()
			names = {}
			for i = 1, numGroups do
				names[i] = wrathSpecNames[i] or ("Talent Set " .. i)
			end
		end

		return multiSpec and names or { "" }
	end,

	--- Number of specializations currently available / unlocked.
	count = function()
		if hasAscensionSpecAPI() then
			return getAscensionCount()
		end
		if hasRetailSpecAPI() then
			return GetNumSpecializations() or 1
		end
		return getNumTalentGroups()
	end,
}

addonTable.utilities.Spec = Spec
