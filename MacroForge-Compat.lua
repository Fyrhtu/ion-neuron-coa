-- Ascension / WotLK 3.3.5 API compatibility shims for MacroForge

local _, addonTable = ...
local MacroForge = addonTable.MacroForge

-- Blizzard defines MICRO_BUTTONS on retail; provide a WotLK fallback.
if not _G.MICRO_BUTTONS then
	_G.MICRO_BUTTONS = {
		"CharacterMicroButton",
		"SpellbookMicroButton",
		"TalentMicroButton",
		"AchievementMicroButton",
		"QuestLogMicroButton",
		"SocialsMicroButton",
		"GuildMicroButton",
		"PVPMicroButton",
		"LFDMicroButton",
		"MainMenuMicroButton",
		"PathToAscensionMicroButton",
	}
end

function MacroForge.GetMicroButtonCount()
	if _G.MICRO_BUTTONS then
		return #_G.MICRO_BUTTONS
	end
	return 8
end

-- Retail exposes RegisterAttributeDriver; 3.3.5 only has RegisterStateDriver.
-- MacroForge's secure-handler state machine depends on RegisterAttributeDriver semantics.
-- Do NOT shim RegisterAttributeDriver → RegisterStateDriver; that causes infinite
-- secure-frame update loops and hard-locks the client on Ascension / WotLK.
-- Ascension may expose RegisterAttributeDriver on a 3.3.5 base; always use the
-- legacy path when retail APIs are absent.
MacroForge.hasNativeAttributeDrivers = not MacroForge.isWoWLegacy
	and type(_G.RegisterAttributeDriver) == "function"
MacroForge.usesLegacyStateDrivers = MacroForge.isWoWLegacy

if MacroForge.usesLegacyStateDrivers and type(_G.UnregisterAttributeDriver) ~= "function" then
	function UnregisterAttributeDriver() end
end

-- Another addon may load an older AceGUI copy without initializing tooltip.
do
	local AceGUI = LibStub("AceGUI-3.0", true)
	if AceGUI and not AceGUI.tooltip then
		AceGUI.tooltip = CreateFrame("GameTooltip", "MacroForgeAceGUITooltip", UIParent, "GameTooltipTemplate")
	end
end

function MacroForge.SetCooldownSwipe(cooldown, drawSwipe)
	if cooldown and cooldown.SetDrawSwipe then
		cooldown:SetDrawSwipe(drawSwipe)
	end
end

function MacroForge.SetCooldownFrame(cooldown, start, duration, enable, reverse, modrate)
	if type(CooldownFrame_Set) ~= "function" then
		return
	end
	if MacroForge.isWoWLegacy then
		CooldownFrame_Set(cooldown, start, duration, enable)
	else
		CooldownFrame_Set(cooldown, start, duration, enable, reverse, modrate)
	end
end

function MacroForge.GetItemCooldownCompat(itemID)
	if C_Container and C_Container.GetItemCooldown then
		return C_Container.GetItemCooldown(itemID)
	end
	return GetItemCooldown(itemID)
end

local function isTexturePath(value)
	return type(value) == "string" and (value:find("\\", 1, true) or value:find("Interface", 1, true))
end

local function isRankString(value)
	return type(value) == "string" and value:find("^Rank ", 1) ~= nil
end

--- Normalize cast/channel API returns across vanilla, WotLK 3.3.5, and Ascension CoA.
--- Returns: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible
local function normalizeCastReturns(...)
	local argc = select("#", ...)
	if argc == 0 then
		return
	end

	local name = select(1, ...)
	if not name then
		return
	end

	local args = {}
	for i = 1, argc do
		args[i] = select(i, ...)
	end

	local texture, startTime, endTime, isTradeSkill, castID, notInterruptible
	local text = name

	-- Retail-style: name, displayName, textureID/file, startMS, endMS, ...
	if type(args[3]) == "number" and tonumber(args[4]) and tonumber(args[5]) then
		text = args[2] or name
		texture = args[3]
		startTime = tonumber(args[4])
		endTime = tonumber(args[5])
		isTradeSkill = args[6]
		castID = args[7]
		notInterruptible = args[8]
		return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
	end

	-- WotLK 3.3.5: name, rank, icon, startMS, endMS, isTradeSkill
	if isTexturePath(args[3]) and tonumber(args[4]) and tonumber(args[5]) then
		texture = args[3]
		startTime = tonumber(args[4])
		endTime = tonumber(args[5])
		isTradeSkill = args[6]
		if type(args[2]) == "string" and not isRankString(args[2]) and not isTexturePath(args[2]) then
			text = args[2]
		end
		return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
	end

	-- Ascension / shifted layout: name, text, rank, icon, startMS, endMS, ...
	if isTexturePath(args[4]) and tonumber(args[5]) and tonumber(args[6]) then
		texture = args[4]
		startTime = tonumber(args[5])
		endTime = tonumber(args[6])
		isTradeSkill = args[7]
		if type(args[2]) == "string" and not isTexturePath(args[2]) then
			text = args[2]
		end
		return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
	end

	-- Vanilla CastingInfo(): name, text, icon, startMS, endMS, isTradeSkill
	if isTexturePath(args[3]) and tonumber(args[4]) and tonumber(args[5]) then
		texture = args[3]
		startTime = tonumber(args[4])
		endTime = tonumber(args[5])
		isTradeSkill = args[6]
		if type(args[2]) == "string" and not isTexturePath(args[2]) then
			text = args[2]
		end
		return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
	end

	-- Last resort: locate icon path and the first two coercible timestamps in order.
	local timeIndex = 1
	for i = 2, argc do
		local value = args[i]
		if not texture and isTexturePath(value) then
			texture = value
		elseif type(value) == "number" or (type(value) == "string" and tonumber(value)) then
			local timeValue = tonumber(value)
			if timeValue then
				if timeIndex == 1 then
					startTime = timeValue
					timeIndex = 2
				elseif timeIndex == 2 then
					endTime = timeValue
					timeIndex = 3
				end
			end
		elseif type(value) == "string" and not isRankString(value) and not isTexturePath(value) then
			text = value
		end
	end

	if startTime and endTime then
		return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible
	end
end

-- WotLK 3.3.5 exposes UnitCastingInfo; vanilla classic used CastingInfo() for player only.
function MacroForge.GetCastingInfo(unit)
	unit = unit or "player"
	if type(UnitCastingInfo) == "function" then
		return normalizeCastReturns(UnitCastingInfo(unit))
	end
	if unit == "player" and type(CastingInfo) == "function" then
		return normalizeCastReturns(CastingInfo())
	end
end

function MacroForge.GetChannelInfo(unit)
	unit = unit or "player"
	if type(UnitChannelInfo) == "function" then
		return normalizeCastReturns(UnitChannelInfo(unit))
	end
	if unit == "player" and type(ChannelInfo) == "function" then
		return normalizeCastReturns(ChannelInfo())
	end
end

-- Retail IsPetActive(); WotLK 3.3.5 uses PetHasActionBar() / UnitExists("pet").
function MacroForge.IsPetActiveCompat()
	if type(IsPetActive) == "function" then
		return IsPetActive()
	end
	if type(PetHasActionBar) == "function" then
		return PetHasActionBar() == 1
	end
	return UnitExists("pet") == 1
end

function MacroForge.IsSpellKnownCompat(spellID, isPet)
	if not spellID or spellID <= 0 or type(IsSpellKnown) ~= "function" then
		return false
	end
	if isPet then
		return IsSpellKnown(spellID, true)
	end
	return IsSpellKnown(spellID)
end