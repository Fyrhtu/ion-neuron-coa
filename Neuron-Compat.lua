-- Ascension / WotLK 3.3.5 API compatibility shims for Neuron

local _, addonTable = ...
local Neuron = addonTable.Neuron

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

function Neuron.GetMicroButtonCount()
	if _G.MICRO_BUTTONS then
		return #_G.MICRO_BUTTONS
	end
	return 8
end

-- Retail exposes RegisterAttributeDriver; 3.3.5 only has RegisterStateDriver.
-- Neuron's secure-handler state machine depends on RegisterAttributeDriver semantics.
-- Do NOT shim RegisterAttributeDriver → RegisterStateDriver; that causes infinite
-- secure-frame update loops and hard-locks the client on Ascension / WotLK.
-- Ascension may expose RegisterAttributeDriver on a 3.3.5 base; always use the
-- legacy path when retail APIs are absent.
Neuron.hasNativeAttributeDrivers = not Neuron.isWoWLegacy
	and type(_G.RegisterAttributeDriver) == "function"
Neuron.usesLegacyStateDrivers = Neuron.isWoWLegacy

if Neuron.usesLegacyStateDrivers and type(_G.UnregisterAttributeDriver) ~= "function" then
	function UnregisterAttributeDriver() end
end

-- Another addon may load an older AceGUI copy without initializing tooltip.
do
	local AceGUI = LibStub("AceGUI-3.0", true)
	if AceGUI and not AceGUI.tooltip then
		AceGUI.tooltip = CreateFrame("GameTooltip", "NeuronAceGUITooltip", UIParent, "GameTooltipTemplate")
	end
end

function Neuron.SetCooldownSwipe(cooldown, drawSwipe)
	if cooldown and cooldown.SetDrawSwipe then
		cooldown:SetDrawSwipe(drawSwipe)
	end
end

function Neuron.SetCooldownFrame(cooldown, start, duration, enable, reverse, modrate)
	if type(CooldownFrame_Set) ~= "function" then
		return
	end
	if Neuron.isWoWLegacy then
		CooldownFrame_Set(cooldown, start, duration, enable)
	else
		CooldownFrame_Set(cooldown, start, duration, enable, reverse, modrate)
	end
end

function Neuron.GetItemCooldownCompat(itemID)
	if C_Container and C_Container.GetItemCooldown then
		return C_Container.GetItemCooldown(itemID)
	end
	return GetItemCooldown(itemID)
end

function Neuron.IsSpellKnownCompat(spellID, isPet)
	if not spellID or spellID <= 0 or type(IsSpellKnown) ~= "function" then
		return false
	end
	if isPet then
		return IsSpellKnown(spellID, true)
	end
	return IsSpellKnown(spellID)
end