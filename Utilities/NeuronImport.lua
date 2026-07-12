-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

-- Import AceDB roots from the legacy Neuron addon SavedVariables (Neuron.lua).
-- WoW loads SV per-addon folder: declaring NeuronProfilesDB on MacroForge does NOT
-- read WTF/.../SavedVariables/Neuron.lua. Neuron must load (or have loaded) first.

local _, addonTable = ...
addonTable.utilities = addonTable.utilities or {}

local NEURON_ADDON = "Neuron"

local function isPlainTable(v)
	return type(v) == "table"
end

--- Count configured action buttons across all AceDB profiles (rough richness metric).
local function countActionButtons(sv)
	if not isPlainTable(sv) or not isPlainTable(sv.profiles) then
		return 0
	end
	local count = 0
	for _, profile in pairs(sv.profiles) do
		if isPlainTable(profile) and isPlainTable(profile.ActionBar) then
			for barId, bar in pairs(profile.ActionBar) do
				if type(barId) == "number" and isPlainTable(bar) and isPlainTable(bar.buttons) then
					for btnId, btn in pairs(bar.buttons) do
						if type(btnId) == "number" and isPlainTable(btn) then
							count = count + 1
						end
					end
				end
			end
		end
	end
	return count
end

local function hasAnyProfile(sv)
	return isPlainTable(sv) and isPlainTable(sv.profiles) and next(sv.profiles) ~= nil
end

--- True if MacroForge SV looks like a fresh/default install (safe to overwrite).
local function looksUnconfigured(sv)
	if not isPlainTable(sv) then
		return true
	end
	if sv._importedFromNeuron then
		return false
	end
	if not hasAnyProfile(sv) then
		return true
	end
	-- Default first-run profiles still have firstRun=true until bars are initialized.
	local anyConfigured = false
	for _, profile in pairs(sv.profiles) do
		if isPlainTable(profile) then
			if profile.firstRun == false and countActionButtons({ profiles = { profile } }) > 0 then
				-- firstRun false alone is not enough (defaults set it after init).
				-- Prefer "has multi-state macro data" as proof of real use.
				if isPlainTable(profile.ActionBar) then
					for barId, bar in pairs(profile.ActionBar) do
						if type(barId) == "number" and isPlainTable(bar) and isPlainTable(bar.buttons) then
							for btnId, btn in pairs(bar.buttons) do
								if type(btnId) == "number" and isPlainTable(btn) then
									for spec = 1, 20 do
										local specData = rawget(btn, spec)
										if isPlainTable(specData) then
											for state, payload in pairs(specData) do
												if type(state) == "string" and isPlainTable(payload)
													and type(payload.macro_Text) == "string"
													and payload.macro_Text ~= "" then
													return false
												end
											end
										end
									end
								end
							end
						end
					end
				end
				anyConfigured = true
			end
		end
	end
	-- No macros found anywhere → treat as unconfigured even if default bars exist.
	return true
end

local function addonExists(name)
	if type(GetAddOnInfo) ~= "function" then
		return false
	end
	local addonName = GetAddOnInfo(name)
	return addonName ~= nil and addonName ~= ""
end

local function isAddonLoaded(name)
	if type(IsAddOnLoaded) == "function" then
		return IsAddOnLoaded(name)
	end
	if type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
		return C_AddOns.IsAddOnLoaded(name)
	end
	return false
end

--- Ensure NeuronProfilesDB is populated from the Neuron addon if possible.
--- @return boolean loaded
--- @return string|nil reason
local function ensureNeuronSVLoaded()
	if hasAnyProfile(NeuronProfilesDB) or countActionButtons(NeuronProfilesDB) > 0 then
		return true
	end

	if not addonExists(NEURON_ADDON) then
		return false, "missing"
	end

	if isAddonLoaded(NEURON_ADDON) then
		-- Loaded but empty
		return hasAnyProfile(NeuronProfilesDB), "empty"
	end

	if type(EnableAddOn) == "function" then
		EnableAddOn(NEURON_ADDON)
	elseif type(C_AddOns) == "table" and type(C_AddOns.EnableAddOn) == "function" then
		C_AddOns.EnableAddOn(NEURON_ADDON)
	end

	local loaded, reason
	if type(LoadAddOn) == "function" then
		loaded, reason = LoadAddOn(NEURON_ADDON)
	elseif type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
		loaded, reason = C_AddOns.LoadAddOn(NEURON_ADDON)
	end

	if not loaded then
		return false, tostring(reason or "load_failed")
	end

	return hasAnyProfile(NeuronProfilesDB) or countActionButtons(NeuronProfilesDB) > 0, "loaded"
end

--- Copy Neuron AceDB root into MacroForgeProfilesDB.
--- @param force boolean overwrite even if MacroForge already looks configured
--- @return boolean ok
--- @return string messageKey
local function importNeuronProfiles(force)
	local okLoad, loadReason = ensureNeuronSVLoaded()
	if not okLoad then
		if loadReason == "missing" then
			return false, "Neuron addon folder not found. Re-install the old Neuron package temporarily (or restore WTF SavedVariables\\Neuron.lua), then run /mf importneuron."
		end
		return false, "Could not load Neuron SavedVariables (reason: " .. tostring(loadReason) .. "). Enable the Neuron addon once, then run /mf importneuron."
	end

	if type(NeuronProfilesDB) ~= "table" then
		return false, "NeuronProfilesDB is missing after load."
	end

	local neuronButtons = countActionButtons(NeuronProfilesDB)
	if neuronButtons == 0 and not hasAnyProfile(NeuronProfilesDB) then
		return false, "NeuronProfilesDB has no profiles/bars to import."
	end

	if not force and type(MacroForgeProfilesDB) == "table" and MacroForgeProfilesDB._importedFromNeuron then
		return false, "Already imported from Neuron (use /mf importneuron force to overwrite)."
	end

	if not force and not looksUnconfigured(MacroForgeProfilesDB) then
		local mfButtons = countActionButtons(MacroForgeProfilesDB)
		if mfButtons >= neuronButtons and mfButtons > 0 then
			return false, "MacroForge already has bar data. Use /mf importneuron force to overwrite from Neuron."
		end
	end

	-- Full AceDB root copy (profiles, profileKeys, namespaces, etc.).
	MacroForgeProfilesDB = CopyTable(NeuronProfilesDB)
	MacroForgeProfilesDB._importedFromNeuron = time and time() or 1

	-- Prefer not to keep both bar systems next login.
	if type(DisableAddOn) == "function" then
		DisableAddOn(NEURON_ADDON)
		if addonExists("Neuron_GUI") then
			DisableAddOn("Neuron_GUI")
		end
	elseif type(C_AddOns) == "table" and type(C_AddOns.DisableAddOn) == "function" then
		C_AddOns.DisableAddOn(NEURON_ADDON)
		if addonExists("Neuron_GUI") then
			C_AddOns.DisableAddOn("Neuron_GUI")
		end
	end

	return true, string.format("Imported Neuron profiles (%d action buttons). Reloading UI…", neuronButtons)
end

addonTable.utilities.NeuronImport = {
	countActionButtons = countActionButtons,
	looksUnconfigured = looksUnconfigured,
	importNeuronProfiles = importNeuronProfiles,
	ensureNeuronSVLoaded = ensureNeuronSVLoaded,
}
