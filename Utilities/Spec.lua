-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
addonTable.utilities = addonTable.utilities or {}

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local Array = addonTable.utilities.Array

-- Ascension CoA Character Advancement specializations (up to 20).
local ASCENSION_MAX_SPECS = 20
-- If the CA API is not ready (or returns 0), still show a usable multi-spec list.
local ASCENSION_FALLBACK_COUNT = 4

local wrathSpecNames = {
	TALENT_SPEC_PRIMARY or "Primary",
	TALENT_SPEC_SECONDARY or "Secondary",
}

---------------------------------------------------------------------------
-- Capability detection
---------------------------------------------------------------------------

local function hasAscensionSpecAPI()
	return type(SpecializationUtil) == "table"
		and type(SpecializationUtil.GetActiveSpecialization) == "function"
		and type(SpecializationUtil.GetNumSpecializations) == "function"
end

local function hasRetailSpecAPI()
	return type(GetSpecialization) == "function"
		and type(GetSpecializationInfo) == "function"
		and type(GetNumSpecializations) == "function"
		and type(GetNumSpecializationsForClassID) == "function"
end

---------------------------------------------------------------------------
-- Ascension CoA: SpecializationUtil
---------------------------------------------------------------------------

local function getAscensionSpecName(index)
	if type(SpecializationUtil.GetSpecializationInfo) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(SpecializationUtil.GetSpecializationInfo, index)
	if not ok then
		return nil
	end
	-- API may return name, or (id, name), or just a string
	if type(a) == "string" and a ~= "" then
		return a
	end
	if type(b) == "string" and b ~= "" then
		return b
	end
	return nil
end

local function getAscensionActive()
	local ok, index = pcall(SpecializationUtil.GetActiveSpecialization)
	if not ok or index == nil then
		return nil, nil
	end
	index = tonumber(index)
	if not index or index < 1 then
		return nil, nil
	end
	local name = getAscensionSpecName(index)
		or (L["Specialization"] and (L["Specialization"] .. " " .. index))
		or ("Spec " .. index)
	return index, name
end

local function getAscensionCount()
	local ok, num = pcall(SpecializationUtil.GetNumSpecializations)
	if ok and type(num) == "number" and num >= 1 then
		if num > ASCENSION_MAX_SPECS then
			return ASCENSION_MAX_SPECS
		end
		return num
	end
	-- Never return 0 — empty multi-spec UI looks like "talent specs are gone"
	return ASCENSION_FALLBACK_COUNT
end

local function getAscensionNames()
	local count = getAscensionCount()
	local names = {}
	for i = 1, count do
		names[i] = getAscensionSpecName(i)
			or ((L["Specialization"] or "Spec") .. " " .. i)
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
-- Public Spec API
---------------------------------------------------------------------------

local Spec; Spec = {
	isAscension = function()
		return hasAscensionSpecAPI()
	end,

	maxSlots = function()
		if hasAscensionSpecAPI() then
			return ASCENSION_MAX_SPECS
		end
		if hasRetailSpecAPI() then
			return 5
		end
		return getNumTalentGroups()
	end,

	active = function(multiSpec)
		local index, name

		if hasAscensionSpecAPI() then
			index, name = getAscensionActive()
			if not index then
				index, name = 1, (L["Specialization"] or "Spec") .. " 1"
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

	names = function(multiSpec)
		if not multiSpec then
			return { "" }
		end

		local names
		if hasAscensionSpecAPI() then
			names = getAscensionNames()
		elseif hasRetailSpecAPI() then
			local n = GetNumSpecializations() or 1
			if n < 1 then n = 1 end
			names = Array.initialize(
				n,
				function(i) return select(2, GetSpecializationInfo(i)) or ("Spec " .. i) end
			)
		else
			local numGroups = getNumTalentGroups()
			names = {}
			for i = 1, numGroups do
				names[i] = wrathSpecNames[i] or ("Talent Set " .. i)
			end
		end

		-- Guarantee at least one entry so multi-spec UI never goes blank
		if type(names) ~= "table" or #names < 1 then
			names = { (L["Specialization"] or "Spec") .. " 1" }
		end
		return names
	end,

	count = function()
		if hasAscensionSpecAPI() then
			return getAscensionCount()
		end
		if hasRetailSpecAPI() then
			local n = GetNumSpecializations() or 1
			return n < 1 and 1 or n
		end
		return getNumTalentGroups()
	end,
}

addonTable.utilities.Spec = Spec
