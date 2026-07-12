-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local MacroForge = addonTable.MacroForge

local L = LibStub("AceLocale-3.0"):GetLocale("MacroForge")
local StanceMap = MacroForge.StanceMap

local function readFormName(index)
	local _, name, _, _, spellId = GetShapeshiftFormInfo(index)
	if (not name or name == "") and type(spellId) == "number" then
		name = GetSpellInfo(spellId)
	end
	return name
end

function MacroForge.UpdateStanceStrings()
	MacroForge:RefreshStanceMap()

	-- these are the results of the visibility macro conditional in the MANAGED_SECONDARY_STATES table
	MacroForge.VISIBILITY_STATES = {
		paged1 = L["Page 1"],
		paged2 = L["Page 2"],
		paged3 = L["Page 3"],
		paged4 = L["Page 4"],
		paged5 = L["Page 5"],
		paged6 = L["Page 6"],
		pet0 = L["No Pet"],
		pet1 = L["Pet Exists"],
		alt0 = L["Alt Up"],
		alt1 = L["Alt Down"],
		ctrl0 = L["Control Up"],
		ctrl1 = L["Control Down"],
		shift0 = L["Shift Up"],
		shift1 = L["Shift Down"],
		stance0 = L["Default"],
		stealth0 = L["No Stealth"],
		stealth1 = L["Stealth"],
		reaction0 = L["Friendly"],
		reaction1 = L["Hostile"],
		combat0 = L["Out of Combat"],
		combat1 = L["In Combat"],
		group0 = L["No Group"],
		group1 = L["Group: Raid"],
		group2 = L["Group: Party"],
		fishing0 = L["No Fishing Pole"],
		fishing1 = L["Fishing Pole"],
		vehicle0 = L["No Vehicle"],
		vehicle1 = L["Vehicle"],
		possess0 = L["No Possess"],
		possess1 = L["Possess"],
		override0 = L["No Override Bar"],
		override1 = L["Override Bar"],
		extrabar0 = L["No Extra Bar"],
		extrabar1 = L["Extra Bar"],
		target0 = L["Has Target"],
		target1 = L["No Target"],
	}

	if not MacroForge.isWoWLegacy then
		MacroForge.VISIBILITY_STATES.dragonriding0 = L["No Dragon Riding"]
		MacroForge.VISIBILITY_STATES.dragonriding1 = L["Dragon Riding"]
	end

	MacroForge.STATES = {
		homestate = L["Home State"],
		laststate = L["Last State"],
		custom0 = L["Custom States"],
	}
	MergeTable(MacroForge.STATES, MacroForge.VISIBILITY_STATES)

	-- Populate stance labels from the dynamic stance map when available.
	if StanceMap and StanceMap.slots and #StanceMap.slots > 0 then
		for slot, entry in ipairs(StanceMap.slots) do
			MacroForge.STATES["stance" .. slot] = entry.name
		end
	else
		for i = 1, GetNumShapeshiftForms() do
			local name = readFormName(i)
			if name and name ~= "" then
				MacroForge.STATES["stance" .. i] = name
			end
		end
	end

	-- Caster Form is special cased just because that's the way it's been historically
	if MacroForge.class == "DRUID" then
		MacroForge.STATES["stance0"] = L["Caster Form"]
	end

	-- stealth shows up with the GetShapeshiftFormInfo, but not the others
	-- Melee is special cased just because that's the way it's been historically
	if MacroForge.class == "ROGUE" then
		MacroForge.STATES["stance0"] = L["Melee"]
		MacroForge.STATES["stance2"] = L["Vanish"]
		MacroForge.STATES["stance3"] = L["Shadow Dance"] --for Subelty Rogues
	end

	if StanceMap and StanceMap:IsCoAClass(MacroForge.class) then
		MacroForge.STATES["stance0"] = L["Humanoid Form"]
	end

	local stanceStates, stanceVisibility = "[stance:0] stance0; [stance:1] stance1; [stance:2] stance2; [stance:3] stance3; [stance:4] stance4; [stance:5] stance5; [stance:6] stance6;"
	if StanceMap then
		stanceStates, stanceVisibility = StanceMap:BuildDriverStrings()
	end

	local stanceLabel =
		(StanceMap and StanceMap:IsCoAClass(MacroForge.class) and L["Form"]) or
		(MacroForge.class == "ROGUE" and L["Stealth"]) or
		(MacroForge.class == "DRUID" and L["Shapeshift"]) or
		(MacroForge.class == "SHAMAN" and L["Shapeshift"]) or
		L["Stance"]

	local stanceRangeStop = StanceMap and StanceMap:GetRangeStop() or 8

	-- the "states" and "visibility" fields are macro conditionals. they will
	-- pass the result of the conditional as "message" into the attribute driver
	-- See "RegisterAttributeDriver" and "SetAttribute"
	-- example: if a priest is in shadowform (stance1) then
	-- "[stance0] noshadow; [stance1] shadow" will make message="shadow"
	MacroForge.MANAGED_HOME_STATES = {
		paged = {
			modifier = "paged",
			homestate = "paged1",
			states = "[bar:1] paged1; [bar:2] paged2; [bar:3] paged3; [bar:4] paged4; [bar:5] paged5; [bar:6] paged6",
			visibility = "[bar:1] paged1; [bar:2] paged2; [bar:3] paged3; [bar:4] paged4; [bar:5] paged5; [bar:6] paged6",
			rangeStart = 2,
			rangeStop = 6,
			localizedName = L["Paged"],
		},

		stance = {
			modifier = "stance",
			homestate = "stance0",
			states = stanceStates,
			visibility = stanceVisibility,
			rangeStart = 1,
			rangeStop = stanceRangeStop,
			localizedName = stanceLabel,
		},

		pet = {
			modifier = "pet",
			homestate = "pet1",
			states = "[nopet] pet1; [@pet,exists,nodead] pet2",
			visibility = "[vehicleui] pet0; [possessbar] pet0; [overridebar] pet0; [nopet] pet0; [pet] pet1",
			rangeStart = 2,
			rangeStop = 3,
			localizedName = L["Pet"],
		},
	}

	MacroForge.MANAGED_SECONDARY_STATES = {
		alt = {
			modifier = "alt",
			states = "[mod:alt] alt1; laststate",
			visibility = "[nomod:alt] alt0; [mod:alt] alt1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Alt"],
		},

		ctrl = {
			modifier = "ctrl",
			states = "[mod:ctrl] ctrl1; laststate",
			visibility = "[nomod:ctrl] ctrl0; [mod:ctrl] ctrl1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Ctrl"],
		},

		shift = {
			modifier = "shift",
			states = "[mod:shift] shift1; laststate",
			visibility = "[nomod:shift] shift0; [mod:shift] shift1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Shift"],
		},

		stealth = {
			modifier = "stealth",
			states = "[stealth] stealth1; laststate",
			visibility = "[nostealth] stealth0; [stealth] stealth1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Stealth"],
		},

		reaction = {
			modifier = "reaction",
			states = "[@target,harm] reaction1; laststate",
			visibility = "[@target,help] reaction0; [@target,harm] reaction1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Reaction"],
		},

		vehicle = {
			modifier = "vehicle",
			states = "[vehicleui] vehicle1; laststate",
			visibility = "[novehicleui] vehicle0; [vehicleui] vehicle1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Vehicle"],
		},

		group = {
			modifier = "group",
			states = "[group:raid] group1; [group:party] group2; laststate",
			visibility = "[nogroup] group0; [group:raid] group1; [group:party] group2",
			rangeStart = 1,
			rangeStop = 2,
			localizedName = L["Group"],
		},

		fishing = {
			modifier = "fishing",
			states = "[worn:fishing poles] fishing1; laststate",
			visibility = "[noworn:fishing poles] fishing0; [worn:fishing poles] fishing1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Fishing"],
		},

		combat = {
			modifier = "combat",
			states = "[combat] combat1; laststate",
			visibility = "[nocombat] combat0; [combat] combat1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Combat"],
		},

		possess = {
			modifier = "possess",
			states = "[possessbar] possess1; laststate",
			visibility = "[nopossessbar] possess0; [possessbar] possess1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Possess"],
		},

		override = {
			modifier = "override",
			states = "[overridebar] override1; laststate",
			visibility = "[nooverridebar] override0; [overridebar] override1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Override"],
		},

		target = {
			modifier = "target",
			states = "[exists] target1; laststate",
			visibility = "[noexists] target0; [exists] target1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Target"],
		},
		indoors = {
			modifier = "indoors",
			states = "[indoors] indoors1; laststate",
			visibility = "[noindoors] indoors0; [indoors] indoors1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Indoors"],
		},
		outdoors = {
			modifier = "outdoors",
			states = "[outdoors] outdoors1; laststate",
			visibility = "[nooutdoors] outdoors0; [outdoors] outdoors1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Outdoors"],
		},
		mounted = {
			modifier = "mounted",
			states = "[mounted] mounted1; laststate",
			visibility = "[nomounted] mounted0; [mounted] mounted1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Mounted"],
		},
		flying = {
			modifier = "flying",
			states = "[flying] flying1; laststate",
			visibility = "[noflying] flying0; [flying] flying1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Flying"],
		},
		help = {
			modifier = "help",
			states = "[help] help1; laststate",
			visibility = "[nohelp] help0; [help] help1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Help"],
		},
		harm = {
			modifier = "harm",
			states = "[harm] harm1; laststate",
			visibility = "[noharm] harm0; [harm] harm1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Harm"],
		},
		resting = {
			modifier = "resting",
			states = "[resting] resting1; laststate",
			visibility = "[noresting] resting0; [resting] resting1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Resting"],
		},
		swimming = {
			modifier = "swimming",
			states = "[swimming] swimming1; laststate",
			visibility = "[noswimming] swimming0; [swimming] swimming1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Swimming"],
		},
	}

	if not MacroForge.isWoWLegacy then
		MacroForge.MANAGED_SECONDARY_STATES.dragonriding = {
			modifier = "dragonriding",
			states = "[bonusbar:5,nopossessbar] dragonriding1; laststate",
			visibility = "[possessbar] dragonriding0; [nobonusbar:5] dragonriding0; [bonusbar:5] dragonriding1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Dragon Riding"],
		}
	end

	MacroForge.MANAGED_OTHER_STATES = {
		custom = {
			modifier = "custom",
			states = "",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Custom"],
		},

		extrabar = {
			modifier = "extrabar",
			states = "[extrabar] extrabar1; laststate",
			visibility = "[noextrabar] extrabar0; [extrabar] extrabar1",
			rangeStart = 1,
			rangeStop = 1,
			localizedName = L["Extrabar"],
		},
	}

	MacroForge.MANAGED_BAR_STATES = {}
	MergeTable(MacroForge.MANAGED_BAR_STATES, MacroForge.MANAGED_HOME_STATES)
	MergeTable(MacroForge.MANAGED_BAR_STATES, MacroForge.MANAGED_SECONDARY_STATES)
	MergeTable(MacroForge.MANAGED_BAR_STATES, MacroForge.MANAGED_OTHER_STATES)
end