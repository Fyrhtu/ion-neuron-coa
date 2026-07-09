-- Neuron is a World of Warcraft(R) user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)
-- Restored 1.4.25-CoA (emergency restore after placeholder; condensed but complete runtime).

local _, addonTable = ...

local Spec = addonTable.utilities.Spec
local DBFixer = addonTable.utilities.DBFixer
local Array = addonTable.utilities.Array
local ButtonBinder = addonTable.overlay.ButtonBinder
local ButtonEditor = addonTable.overlay.ButtonEditor

local function GetBarEditor()
	return addonTable.overlay.BarEditor
end

addonTable.Neuron = LibStub("AceAddon-3.0"):NewAddon(CreateFrame("Frame", nil, UIParent), "Neuron", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0", "AceSerializer-3.0")
local Neuron = addonTable.Neuron

local DB
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local LATEST_VERSION_NUM = "1.4.25-CoA"

Neuron.bars = {}
Neuron.registeredBarData = {}
Neuron.itemCache = {}
Neuron.spellCache = {}
Neuron.barEditMode = false
Neuron.buttonEditMode = false
Neuron.bindingMode = false

local _, _, _, interfaceVersion = GetBuildInfo()
interfaceVersion = tonumber(interfaceVersion) or 99999
local hasRetailAPIs = type(GetNumSpecializationsForClassID) == "function" and type(GetProfessions) == "function"
Neuron.isWoWLegacy = not hasRetailAPIs or interfaceVersion <= 30300
Neuron.isWoWClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
Neuron.isWoWWrathClassic = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
Neuron.isWoWRetail = hasRetailAPIs and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
Neuron.isWoWWotLK = Neuron.isWoWWrathClassic or Neuron.isWoWLegacy or not hasRetailAPIs
Neuron.isAscensionCoA = Neuron.isWoWLegacy

Neuron.STRATAS = { [1]="BACKGROUND",[2]="LOW",[3]="MEDIUM",[4]="HIGH",[5]="DIALOG",[6]="TOOLTIP" }
Neuron.TIMERLIMIT = 4
Neuron.SNAPTO_TOLERANCE = 28
Neuron.DEBUG = true

function Neuron:OnInitialize()
	Neuron.db = LibStub("AceDB-3.0"):New("NeuronProfilesDB", addonTable.databaseDefaults)
	Neuron.db = DBFixer.databaseMigration(Neuron.db)
	DB = Neuron.db.profile
	Neuron.db.RegisterCallback(Neuron, "OnProfileChanged", "RefreshConfig")
	Neuron.db.RegisterCallback(Neuron, "OnProfileCopied", "RefreshConfig")
	Neuron.db.RegisterCallback(Neuron, "OnProfileReset", "RefreshConfig")
	Neuron.db.RegisterCallback(Neuron, "OnDatabaseReset", "RefreshConfig")
	Neuron.itemCache = DB.NeuronItemCache
	Neuron.spellCache = DB.NeuronSpellCache
	Neuron.class = select(2, UnitClass("player"))
	Neuron:UpdateStanceStrings()
	StaticPopupDialogs["ReloadUI"] = { text = L["ReloadUI"], button1 = OKAY, OnAccept = function() ReloadUI() end, preferredIndex = 3 }
	Neuron:Minimap_IconInitialize()
	Neuron.registeredBarData = Neuron:RegisterBars(DB)
	if DB.firstRun then Neuron:InitializeEmptyDatabase(DB) end
	Neuron:CreateBarsAndButtons(DB)
end

function Neuron:OnEnable()
	if Neuron.DEBUG then _G.Neuron = Neuron end
	Neuron:RegisterEvent("PLAYER_REGEN_DISABLED")
	Neuron:RegisterEvent("PLAYER_REGEN_ENABLED")
	Neuron:RegisterEvent("PLAYER_ENTERING_WORLD")
	Neuron:RegisterEvent("SPELLS_CHANGED")
	Neuron:RegisterEvent("CHARACTER_POINTS_CHANGED")
	Neuron:RegisterEvent("LEARNED_SPELL_IN_TAB")
	Neuron:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	Neuron:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	if type(SpecializationUtil) == "table" and type(SpecializationUtil.GetActiveSpecialization) == "function" then
		Neuron:RegisterEvent("ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "OnTalentGroupChanged")
	end
	if Neuron.isWoWRetail or Neuron.isWoWWotLK or Neuron.isAscensionCoA then
		Neuron:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnTalentGroupChanged")
		Neuron:RegisterEvent("PLAYER_TALENT_UPDATE", "OnTalentGroupChanged")
	end
	Neuron:UpdateStanceStrings()
	Neuron:HookGameMenuFrame()
	Neuron:LoginMessage()
	for _,v in pairs(Neuron.bars) do v:Load() end
	if Neuron.isWoWRetail and GetCVar and GetCVar("ActionButtonUseKeyDown") then SetCVar("ActionButtonUseKeyDown", 0) end
	Neuron.NeuronGUI:LoadInterfaceOptions()
end

function Neuron:OnDisable()
	if Neuron.isWoWRetail and GetCVar and GetCVar("ActionButtonUseKeyDown") then SetCVar("ActionButtonUseKeyDown", 1) end
end

function Neuron:PLAYER_REGEN_DISABLED()
	if Neuron.buttonEditMode then Neuron:ToggleButtonEditMode(false) end
	if Neuron.bindingMode then Neuron:ToggleBindingMode(false) end
	if Neuron.barEditMode then Neuron:ToggleBarEditMode(false) end
end

function Neuron:PLAYER_REGEN_ENABLED()
	if Neuron.pendingStanceRefresh then
		Neuron.pendingStanceRefresh = nil
		Neuron:OnStanceMapUpdated()
	end
	Neuron:RefreshActionButtonVisuals()
end

function Neuron:OnTalentGroupChanged()
	for _, bar in pairs(Neuron.bars) do
		if bar.class == "ActionBar" and bar.GetMultiSpec and bar:GetMultiSpec() and not InCombatLockdown() then
			for _, button in pairs(bar.buttons) do
				if button.UpdateButtonSpec then button:UpdateButtonSpec() end
			end
			bar:Load()
		end
	end
	Neuron:UpdateSpellCache()
	Neuron:UpdateStanceStrings()
	if Neuron.buttonEditMode and Neuron.NeuronGUI and Neuron.NeuronGUI.RefreshEditor then
		Neuron.NeuronGUI:RefreshEditor("button")
	end
end

function Neuron:RefreshActionButtonVisuals()
	for _, bar in pairs(Neuron.bars) do
		if bar.class == "ActionBar" and bar.buttons then
			for _, button in pairs(bar.buttons) do
				local state = button.GetAttribute and button:GetAttribute("activestate")
				if (not state or state == "") and bar.handler then state = bar.handler:GetAttribute("activestate") end
				state = state or "homestate"
				state = tostring(state):match("([^:]+)$") or state
				if button.statedata and type(button.statedata[state]) == "table" then button.data = button.statedata[state] end
				if button.UpdateAll then button:UpdateAll() end
			end
		end
	end
end

function Neuron:HookGameMenuFrame()
	local menuFrame = _G.GameMenuFrame
	if not menuFrame or type(menuFrame.SetScript) ~= "function" then return end
	if Neuron:IsHooked(menuFrame, "OnUpdate") then return end
	Neuron:HookScript(menuFrame, "OnUpdate", function(self)
		if Neuron.barEditMode then HideUIPanel(self); Neuron:ToggleBarEditMode(false) end
		if Neuron.buttonEditMode then HideUIPanel(self); Neuron:ToggleButtonEditMode(false) end
		if Neuron.bindingMode then HideUIPanel(self); Neuron:ToggleBindingMode(false) end
	end)
end

function Neuron:PLAYER_ENTERING_WORLD()
	DB.firstRun = false
	Neuron:HookGameMenuFrame()
	Neuron:UpdateSpellCache()
	Neuron:UpdateStanceStrings()
	if IsAddOnLoaded("Titan") then TitanUtils_AddonAdjust("MainMenuBar", true) end
	Neuron:HideBlizzardUI(DB)
end

function Neuron:ACTIVE_TALENT_GROUP_CHANGED() Neuron:OnTalentGroupChanged() end
function Neuron:LEARNED_SPELL_IN_TAB() Neuron:UpdateSpellCache(); Neuron:UpdateStanceStrings() end
function Neuron:CHARACTER_POINTS_CHANGED() Neuron:UpdateSpellCache(); Neuron:UpdateStanceStrings() end
function Neuron:SPELLS_CHANGED() Neuron:UpdateSpellCache(); Neuron:UpdateStanceStrings() end
function Neuron:UPDATE_SHAPESHIFT_FORMS()
	if InCombatLockdown() then Neuron.pendingStanceRefresh = true; return end
	Neuron:OnStanceMapUpdated()
end
function Neuron:UPDATE_SHAPESHIFT_FORM() Neuron:RefreshActionButtonVisuals() end

function Neuron:RefreshConfig(db, profile)
	StaticPopup_Show("ReloadUI")
	Neuron.pendingReload = true
end

function Neuron:LoginMessage()
	if not DB.updateWarning or DB.updateWarning ~= LATEST_VERSION_NUM then
		if not IsAddOnLoaded("Masque") then
			print(" "); print("    You do not currently have Masque installed or enabled."); print(" ")
		end
	end
	DB.updateWarning = LATEST_VERSION_NUM
	if Spec.active(true) > 4 then
		print(" "); Neuron:Print("Warning: You do not currently have a specialization selected. Changes to any buttons which have 'Multi Spec' set will not persist."); print(" ")
	end
end

function Neuron:SetSpellInfo(index, bookType, spellType, spellName, spellID, icon, altName, altSpellID, altIcon)
	local curSpell = {}
	curSpell.index = index; curSpell.booktype = bookType; curSpell.spellType = spellType
	curSpell.spellName = spellName; curSpell.spellID = spellID; curSpell.icon = icon
	curSpell.altName = altName; curSpell.altSpellID = altSpellID; curSpell.altIcon = altIcon
	return curSpell
end

function Neuron:UpdateSpellCache()
	local sIndexMax = 0
	local numTabs = GetNumSpellTabs()
	for i=1,numTabs do local _, _, _, numSlots = GetSpellTabInfo(i); sIndexMax = sIndexMax + numSlots end
	for i = 1,sIndexMax do
		local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
		local spellType, spellID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
		local isPassive = spellName and IsPassiveSpell(i, BOOKTYPE_SPELL)
		local icon = GetSpellTexture(spellID)
		if (spellName and spellType ~= "FUTURESPELL") and not isPassive then
			local altName, altSpellID, altIcon
			if not Neuron.isWoWLegacy then
				altName, _, altIcon, _, _, _, altSpellID = GetSpellInfo(spellName)
				if spellID == altSpellID then altSpellID = nil; altName = nil; altIcon = nil end
			end
			local spellData = Neuron:SetSpellInfo(i, BOOKTYPE_SPELL, spellType, spellName, spellID, icon, altName, altSpellID, altIcon)
			Neuron.spellCache[(spellName):lower()] = spellData
			Neuron.spellCache[(spellName):lower().."()"] = spellData
			if altName and altName ~= spellName then
				local altSpellData = Neuron:SetSpellInfo(i, BOOKTYPE_SPELL, spellType, altName, altSpellID, altIcon, spellName, spellID, icon)
				Neuron.spellCache[(altName):lower()] = altSpellData
				Neuron.spellCache[(altName):lower().."()"] = altSpellData
			end
		end
	end
end

function Neuron:ToggleMainMenu()
	InterfaceOptionsFrame_OpenToCategory("Neuron"); InterfaceOptionsFrame_OpenToCategory("Neuron")
end

function Neuron:SelectFirstBar()
	if Neuron.currentBar then return Neuron.currentBar end
	for _, bar in ipairs(Neuron.bars) do Neuron.Bar.ChangeSelectedBar(bar); return bar end
	return nil
end

function Neuron:EnsureBarsExist()
	if #Neuron.bars > 0 then return end
	local empty = true
	for _, reg in pairs(Neuron.registeredBarData) do
		for _, entry in pairs(reg.barDB) do if entry then empty = false; break end end
		if not empty then break end
	end
	if empty then Neuron:InitializeEmptyDatabase(DB) end
	Neuron:CreateBarsAndButtons(DB)
	for _, bar in pairs(Neuron.bars) do bar:Load() end
end

function Neuron:ToggleBarEditMode(show)
	if show then
		Neuron:EnsureBarsExist(); Neuron.barEditMode = true
		Neuron:ToggleButtonEditMode(false); Neuron:ToggleBindingMode(false)
		for _, bar in pairs(Neuron.bars) do bar:PrepareForEditMode(false) end
		Neuron:SelectFirstBar()
		if Neuron.currentBar then Neuron.currentBar:PrepareForEditMode(true) end
	else
		Neuron.barEditMode = false
		for _, bar in pairs(Neuron.bars) do
			local overlay = bar.editFrame; bar.editFrame = nil
			if overlay then GetBarEditor().free(overlay) end
			bar:LeaveEditMode()
		end
	end
end

function Neuron:ToggleButtonEditMode(show)
	local isActionBar = function(bar) return bar and bar.class == "ActionBar" end
	local isStatusBar = function(bar)
		return bar and (bar.class == "XPBar" or bar.class == "RepBar" or bar.class == "CastBar" or bar.class == "MirrorBar")
	end
	local bars = Array.concatenate(Array.filter(isActionBar, Neuron.bars), Array.filter(isStatusBar, Neuron.bars))
	if show then
		Neuron.buttonEditMode = true
		Neuron:ToggleBarEditMode(false); Neuron:ToggleBindingMode(false)
		local currentButton = Neuron.currentButton or ((isActionBar(Neuron.currentBar) or isStatusBar(Neuron.currentBar)) and unpack(Neuron.currentBar.buttons)) or Array.foldl(function(button, bar) return button or unpack(bar.buttons) end, nil, bars)
		if not currentButton then Neuron.buttonEditMode = false; return end
		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				button.editFrame = button.editFrame or ButtonEditor.allocate(button, isActionBar(bar) and "corners" or "sides", function(btn)
					Neuron.Button.ChangeSelectedButton(btn)
					if addonTable.NeuronEditor then Neuron.NeuronGUI:RefreshEditor() end
				end)
			end
			bar:UpdateObjectVisibility(true); bar:UpdateBarStatus(true); bar:UpdateObjectStatus(); bar:UpdateObjectUsability()
		end
		Neuron.Button.ChangeSelectedButton(currentButton)
		ButtonEditor.activate(currentButton.editFrame)
	else
		Neuron.buttonEditMode = false
		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				if button.editFrame then ButtonEditor.free(button.editFrame); button.editFrame = nil end
			end
			bar:UpdateObjectVisibility(); bar:UpdateBarStatus(); bar:UpdateObjectStatus(); bar:UpdateObjectUsability()
		end
	end
end

local function processKeyBinding(targetButton, key)
	if targetButton.keys and targetButton.keys.hotKeyLock then
		UIErrorsFrame:AddMessage(L["Bindings_Locked_Notice"], 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME); return
	end
	if key == "ESCAPE" then
		ClearOverrideBindings(targetButton); targetButton.keys.hotKeys = ":"; targetButton:ApplyBindings()
	elseif key then
		for _, bar in pairs(Neuron.bars) do
			for _, button in pairs(bar.buttons) do
				if button.keys and targetButton ~= button and not button.keys.hotKeyLock then
					button.keys.hotKeys:gsub("[^:]+", function(binding)
						if key == binding then
							local newkey = binding:gsub("%-", "%%-")
							button.keys.hotKeys = button.keys.hotKeys:gsub(newkey..":", "")
							button:ApplyBindings()
						end
					end)
				end
			end
		end
		local found
		targetButton.keys.hotKeys:gsub("[^:]+", function(binding) if binding == key then found = true end end)
		if not found then targetButton.keys.hotKeys = targetButton.keys.hotKeys..key..":" end
		targetButton:ApplyBindings()
	end
end

function Neuron:ToggleBindingMode(show)
	local isBindable = function(bar)
		return bar and (bar.class == "ActionBar" or bar.class == "ExtraBar" or bar.class == "ZoneAbilityBar" or bar.class == "PetBar")
	end
	local bars = Array.filter(isBindable, Neuron.bars)
	if show then
		Neuron.bindingMode = true; Neuron:ToggleButtonEditMode(false); Neuron:ToggleBarEditMode(false)
		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				button.keybindFrame = button.keybindFrame or ButtonBinder.allocate(button, processKeyBinding)
			end
			bar:UpdateObjectVisibility(true); bar:UpdateBarStatus(true); bar:UpdateObjectStatus(); bar:UpdateObjectUsability()
		end
	else
		Neuron.bindingMode = false
		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				if button.keybindFrame then ButtonBinder.free(button.keybindFrame); button.keybindFrame = nil end
			end
			bar:UpdateObjectVisibility(); bar:UpdateBarStatus(); bar:UpdateObjectStatus(); bar:UpdateObjectUsability()
		end
	end
end

function Neuron:GetSerializedAndCompressedProfile()
	local uncompressed = Neuron:Serialize(Neuron.db.profile)
	local compressed = LibDeflate:CompressZlib(uncompressed)
	return LibDeflate:EncodeForPrint(compressed)
end

function Neuron:SetSerializedAndCompressedProfile(input)
	if input == "" then Neuron:Print(L["No data to import."].." "..L["Aborting."]); return end
	local decoded = LibDeflate:DecodeForPrint(input)
	if decoded == nil then Neuron:Print(L["Decoding failed."].." "..L["Aborting."]); return end
	local uncompressed = LibDeflate:DecompressZlib(decoded)
	if uncompressed == nil then Neuron:Print(L["Decompression failed."].." "..L["Aborting."]); return end
	local result, newProfile = Neuron:Deserialize(uncompressed)
	if result == true and newProfile then
		for k,v in pairs(newProfile) do
			if type(v) == "table" then Neuron.db.profile[k] = CopyTable(v) else Neuron.db.profile[k] = v end
		end
		ReloadUI()
	else
		Neuron:Print(L["Data import Failed."].." "..L["Aborting."])
	end
end
