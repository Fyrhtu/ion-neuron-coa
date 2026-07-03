-- Neuron CoA / Ascension 3.3.5 stance map
-- Detects custom class forms from the client shapeshift API and builds
-- macro conditionals compatible with both WotLK bonus bars and CoA forms.

local _, addonTable = ...
local Neuron = addonTable.Neuron

local format = string.format
local tinsert = table.insert
local pairs, ipairs = pairs, ipairs

Neuron.StanceMap = Neuron.StanceMap or {}

local StanceMap = Neuron.StanceMap

StanceMap.MAX_SLOTS = 16

-- WotLK spell-id metadata: canonical id, bonusbar/form index, and driver type.
local SPELL_STANCE_META = {
	[2457]  = { id = "battle", index = 1 },
	[71]    = { id = "def", index = 2 },
	[2458]  = { id = "berserker", index = 3 },
	[5487]  = { id = "bear", index = 3 },
	[9634]  = { id = "bear", index = 3 },
	[768]   = { id = "cat", index = 1 },
	[24858] = { id = "moonkin", index = 4 },
	[33891] = { id = "treeoflife", index = 2 },
	[1784]  = { id = "stealth", index = 1 },
	[51713] = { id = "shadowdance", index = 2, uiIndex = 1 },
	[15473] = { id = "shadowform", index = 1 },
	[59672] = { id = "metamorphosis", index = 2, type = "form", uiIndex = 1 },
}

-- Ascension Conquest of Azeroth custom classes (Area 52 / CoA realm).
StanceMap.COA_CLASSES = {
	HERO = true,
	NECROMANCER = true,
	PYROMANCER = true,
	CULTIST = true,
	STARCALLER = true,
	SUNCLERIC = true,
	TINKER = true,
	RUNEMASTER = true,
	PRIMAALIST = true,
	REAPER = true,
	VENOMANCER = true,
	CHRONOMANCER = true,
	BLOODMAGE = true,
	GUARDIAN = true,
	STORMBRINGER = true,
	FELSWORN = true,
	BARBARIAN = true,
	WITCH_DOCTOR = true,
	WITCH_HUNTER = true,
	KNIGHT_OF_XOROTH = true,
	TEMPLAR = true,
	RANGED = true,
	WITCHDOCTOR = true,
	DEMONHUNTER = true,
	WITCHHUNTER = true,
	FLESHWARDEN = true,
	MONK = true,
	SONOFARUGAL = true,
	RANGER = true,
	PROPHET = true,
	WILDWALKER = true,
	SPIRITMAGE = true,
}

local CLASSIC_STANCE_CLASSES = {
	WARRIOR = true,
	DRUID = true,
	ROGUE = true,
	PRIEST = true,
	WARLOCK = true,
	SHAMAN = true,
	HERO = true,
}

local function slugify(name, index)
	if type(name) ~= "string" or name == "" then
		return "form_" .. index
	end
	return "form_" .. name:gsub("%s+", "_"):lower():gsub("[^%w_]", "")
end

local function lookupMetaByName(name)
	for spellId, meta in pairs(SPELL_STANCE_META) do
		local spellName = GetSpellInfo(spellId)
		if spellName and spellName == name then
			return meta, spellId
		end
	end
end

local function resolveUiIndex(i, meta)
	if meta and meta.uiIndex then
		return meta.uiIndex
	end
	return i
end

local function readFormInfo(index)
	local texture, name, isActive, isCastable, spellId = GetShapeshiftFormInfo(index)
	if (not name or name == "") and type(spellId) == "number" then
		name = GetSpellInfo(spellId)
	end
	return texture, name, isActive, isCastable, spellId
end

local function buildEntry(uiIndex, name, meta, class)
	local isCoA = class and StanceMap.COA_CLASSES[class]
	return {
		id = meta and meta.id or slugify(name, uiIndex),
		name = name,
		index = meta and meta.index or uiIndex,
		type = meta and meta.type or (isCoA and "form" or "bonusbar"),
		uiIndex = uiIndex,
		slot = uiIndex,
	}
end

function StanceMap:IsCoAClass(class)
	return class and self.COA_CLASSES[class] or false
end

function StanceMap:UsesLegacyDrivers()
	return Neuron.isWoWWotLK
end

function StanceMap:PlayerHasStances(class)
	if (GetNumShapeshiftForms() or 0) > 0 then
		return true
	end
	return self:IsCoAClass(class) or CLASSIC_STANCE_CLASSES[class] or false
end

function StanceMap:UsesProwlHack(class)
	return class == "DRUID" or class == "HERO" or self:IsCoAClass(class)
end

function StanceMap:GetConditionPrefix(mapIndex)
	local entry = self.slots and self.slots[tonumber(mapIndex)]
	if entry and entry.index and self:UsesLegacyDrivers() then
		return (entry.type or "bonusbar") .. ":" .. entry.index
	end
	return "stance:" .. mapIndex
end

function StanceMap:GetEntryForSlot(slot)
	return self.slots and self.slots[slot]
end

function StanceMap:GetNumSlots()
	return self.numSlots or 0
end

function StanceMap:Refresh(class)
	class = class or Neuron.class
	self.slots = {}
	self.numSlots = 0

	if not class then
		return self.slots
	end

	local seen = {}
	local numForms = GetNumShapeshiftForms() or 0

	for i = 1, numForms do
		local _, name = readFormInfo(i)
		if name and name ~= "" then
			local meta = lookupMetaByName(name)
			local uiIndex = resolveUiIndex(i, meta)
			local id = meta and meta.id or slugify(name, uiIndex)
			if not seen[id] then
				local entry = buildEntry(uiIndex, name, meta, class)
				entry.slot = #self.slots + 1
				tinsert(self.slots, entry)
				seen[id] = true
			end
		end
	end

	self.numSlots = #self.slots

	-- Ascension swaps metamorphosis / shadow dance UI ordering quirks.
	local metaName = GetSpellInfo(59672)
	if metaName and self.slots[1] and self.slots[1].name == metaName and self.slots[2] then
		self.slots[1], self.slots[2] = self.slots[2], self.slots[1]
	end

	local danceName = GetSpellInfo(51713)
	if danceName and self.slots[1] and self.slots[1].name == danceName then
		local dance = table.remove(self.slots, 1)
		tinsert(self.slots, dance)
	end

	return self.slots
end

function StanceMap:BuildDriverStrings()
	local states = { "[stance:0] stance0" }
	local visibility = { "[stance:0] stance0" }

	if self:UsesLegacyDrivers() then
		for slot, entry in ipairs(self.slots or {}) do
			if entry.index then
				local cond = format("[%s:%s]", entry.type or "bonusbar", entry.index)
				states[#states + 1] = format("%s stance%d", cond, slot)
				visibility[#visibility + 1] = format("%s stance%d", cond, slot)
			end
		end
	else
		local maxSlot = math.min(self.numSlots, 6)
		for i = 1, maxSlot do
			states[#states + 1] = format("[stance:%d] stance%d", i, i)
			visibility[#visibility + 1] = format("[stance:%d] stance%d", i, i)
		end
	end

	return table.concat(states, "; ") .. ";", table.concat(visibility, "; ") .. ";"
end

function StanceMap:GetRangeStop()
	return math.max(8, math.min(self.MAX_SLOTS, (self.numSlots or 0) + 1))
end

function Neuron:RefreshStanceMap()
	if not self.StanceMap then
		return
	end
	self.StanceMap:Refresh(self.class)
end

function Neuron:OnStanceMapUpdated()
	self:RefreshStanceMap()
	self:UpdateStanceStrings()

	for _, bar in pairs(self.bars) do
		if bar.data.stance then
			bar:SetRemap_Stance()
		end
		bar.stateschanged = true
		if not InCombatLockdown() then
			bar:UpdateBarStatus()
		end
	end
end