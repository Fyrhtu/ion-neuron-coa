-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)


local _, addonTable = ...

local Spec = addonTable.utilities.Spec
local DBFixer = addonTable.utilities.DBFixer
local NeuronImport = addonTable.utilities.NeuronImport
local Array = addonTable.utilities.Array
local ButtonBinder = addonTable.overlay.ButtonBinder
local ButtonEditor = addonTable.overlay.ButtonEditor

local function GetBarEditor()
	return addonTable.overlay.BarEditor
end

---@class MacroForge : AceAddon-3.0 @define The main addon object for the MacroForge Action Bar addon
addonTable.MacroForge = LibStub("AceAddon-3.0"):NewAddon(CreateFrame("Frame", nil, UIParent), "MacroForge", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0", "AceSerializer-3.0")
local MacroForge = addonTable.MacroForge

-- Shared with LoadOnDemand MacroForge_GUI (editor + AceGUI stack).
MacroForge.package = addonTable

local DB

local LibDeflate = LibStub:GetLibrary("LibDeflate")
local L = LibStub("AceLocale-3.0"):GetLocale("MacroForge")

local LATEST_VERSION_NUM = "1.5.1-CoA" --this variable is set to popup a welcome message upon updating/installing. Only change it if you want to pop up a message after the users next update

--prepare the MacroForge table with some sub-tables that will be used down the road
MacroForge.bars = {} --this table will be our main handle for all of our bars.

MacroForge.registeredBarData = {}

--these are the database tables that are going to hold our data. They are global because every .lua file needs access to them
MacroForge.itemCache = {} --Stores a cache of all items that have been seen by a MacroForge button
MacroForge.spellCache = {} --Stores a cache of all spells that have been seen by a MacroForge button

MacroForge.barEditMode = false
MacroForge.buttonEditMode = false
MacroForge.bindingMode = false

-- Ascension CoA uses a 3.3.5 client that may report WOW_PROJECT_MAINLINE without retail APIs.
local _, _, _, interfaceVersion = GetBuildInfo()
interfaceVersion = tonumber(interfaceVersion) or 99999
local hasRetailAPIs = type(GetNumSpecializationsForClassID) == "function"
	and type(GetProfessions) == "function"

MacroForge.isWoWLegacy = not hasRetailAPIs or interfaceVersion <= 30300
MacroForge.isWoWClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
MacroForge.isWoWWrathClassic = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
MacroForge.isWoWRetail = hasRetailAPIs and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
MacroForge.isWoWWotLK = MacroForge.isWoWWrathClassic or MacroForge.isWoWLegacy or not hasRetailAPIs
MacroForge.isAscensionCoA = MacroForge.isWoWLegacy

MacroForge.STRATAS = {
	[1] = "BACKGROUND",
	[2] = "LOW",
	[3] = "MEDIUM",
	[4] = "HIGH",
	[5] = "DIALOG",
	[6] = "TOOLTIP"
}

MacroForge.TIMERLIMIT = 4
MacroForge.SNAPTO_TOLERANCE = 28

MacroForge.DEBUG = true

-------------------------------------------------------------------------
--------------------Start of Functions-----------------------------------
-------------------------------------------------------------------------

--- **OnInitialize**, which is called directly after the addon is fully loaded.
--- do init tasks here, like loading the Saved Variables
--- or setting up slash commands.
function MacroForge:OnInitialize()
	-- Import legacy Neuron SavedVariables (from the Neuron addon folder / Neuron.lua).
	-- OptionalDeps loads Neuron first when enabled; otherwise we try LoadAddOn once.
	local imported, importMsg = NeuronImport.importNeuronProfiles(false)
	if imported then
		MacroForge:Print(importMsg)
		-- Re-init cleanly with the new MacroForgeProfilesDB contents.
		MacroForge:RegisterChatCommand("macroforge", "slashHandler")
		MacroForge:RegisterChatCommand("mf", "slashHandler")
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(0.05, function() ReloadUI() end)
		else
			ReloadUI()
		end
		return
	elseif importMsg and NeuronImport.looksUnconfigured(MacroForgeProfilesDB) then
		-- Only nags when MF still looks empty/default so we do not spam configured users.
		MacroForge:Print("Neuron profile import: " .. importMsg)
	end

	MacroForge.db = LibStub("AceDB-3.0"):New("MacroForgeProfilesDB", addonTable.databaseDefaults)

	--Check if the current database needs to be migrated, and attempt the migration
	MacroForge.db = DBFixer.databaseMigration(MacroForge.db)
	DB = MacroForge.db.profile

	MacroForge.db.RegisterCallback(MacroForge, "OnProfileChanged", "RefreshConfig")
	MacroForge.db.RegisterCallback(MacroForge, "OnProfileCopied", "RefreshConfig")
	MacroForge.db.RegisterCallback(MacroForge, "OnProfileReset", "RefreshConfig")
	MacroForge.db.RegisterCallback(MacroForge, "OnDatabaseReset", "RefreshConfig")

	--load saved variables into working variable containers
	MacroForge.itemCache = DB.MacroForgeItemCache or DB.NeuronItemCache or {}
	MacroForge.spellCache = DB.MacroForgeSpellCache or DB.NeuronSpellCache or {}
	DB.MacroForgeItemCache = MacroForge.itemCache
	DB.MacroForgeSpellCache = MacroForge.spellCache

	MacroForge.class = select(2, UnitClass("player"))
	MacroForge:UpdateStanceStrings()

	StaticPopupDialogs["ReloadUI"] = {
		text = L["ReloadUI"],
		button1 = OKAY,
		OnAccept = function()
			ReloadUI()
		end,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}

	--Initialize the Minimap Icon
	MacroForge:Minimap_IconInitialize()

	-- Slash commands
	MacroForge:RegisterChatCommand("macroforge", "slashHandler")
	MacroForge:RegisterChatCommand("mf", "slashHandler")

	--build all bar and button frames and run initial setup
	MacroForge.registeredBarData = MacroForge:RegisterBars(DB)
	if DB.firstRun then
		MacroForge:InitializeEmptyDatabase(DB)
	end
	MacroForge:CreateBarsAndButtons(DB)
end

--- /mf importneuron [force] — pull bars/profiles from legacy Neuron SavedVariables.
function MacroForge:ImportNeuronCommand(arg)
	local force = arg and tostring(arg):lower() == "force"
	local ok, msg = NeuronImport.importNeuronProfiles(force)
	if ok then
		MacroForge:Print(msg)
		ReloadUI()
	else
		MacroForge:Print("Import failed: " .. tostring(msg))
	end
end

--- **OnEnable** which gets called during the PLAYER_LOGIN event, when most of the data provided by the game is already present.
--- Do more initialization here, that really enables the use of your addon.
--- Register Events, Hook functions, Create Frames, Get information from
--- the game that wasn't available in OnInitialize
function MacroForge:OnEnable()
	if MacroForge.DEBUG then
		_G.MacroForge = MacroForge
	end

	MacroForge:RegisterEvent("PLAYER_REGEN_DISABLED")
	MacroForge:RegisterEvent("PLAYER_REGEN_ENABLED")
	MacroForge:RegisterEvent("PLAYER_ENTERING_WORLD")
	MacroForge:RegisterEvent("SPELLS_CHANGED")
	MacroForge:RegisterEvent("CHARACTER_POINTS_CHANGED")
	MacroForge:RegisterEvent("LEARNED_SPELL_IN_TAB")
	MacroForge:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	MacroForge:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

	-- Multi-spec (Ascension Character Advancement specializations)
	if type(SpecializationUtil) == "table" and type(SpecializationUtil.GetActiveSpecialization) == "function" then
		MacroForge:RegisterEvent("ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "OnTalentGroupChanged")
	end
	if MacroForge.isWoWRetail or MacroForge.isWoWWotLK or MacroForge.isAscensionCoA then
		MacroForge:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnTalentGroupChanged")
		MacroForge:RegisterEvent("PLAYER_TALENT_UPDATE", "OnTalentGroupChanged")
	end

	MacroForge:UpdateStanceStrings()

	--this allows for the "Esc" key to disable the Edit Mode instead of bringing up the game menu, but only if an edit mode is activated.

	MacroForge:HookGameMenuFrame()

	MacroForge:LoginMessage()

	--Load all bars and buttons
	for _,v in pairs(MacroForge.bars) do
		v:Load()
	end

	--this is a hack for 10.0. They broke everything with regard to the way addons interface with
	--SecureActionButtons see SecureTemplates.lua SecureActionButton_OnClick() for more information
	if MacroForge.isWoWRetail and GetCVar and GetCVar("ActionButtonUseKeyDown") then
		SetCVar("ActionButtonUseKeyDown", 0)
	end

	-- Interface options / AceGUI editor load on demand via MacroForge:EnsureGUI()
end

--- **OnDisable**, which is only called when your addon is manually being disabled.
--- Unhook, Unregister Events, Hide frames that you created.
--- You would probably only use an OnDisable if you want to
--- build a "standby" mode, or be able to toggle modules on/off.
function MacroForge:OnDisable()
	if MacroForge.isWoWRetail and GetCVar and GetCVar("ActionButtonUseKeyDown") then
		SetCVar("ActionButtonUseKeyDown", 1)
	end
end

-------------------------------------------------

function MacroForge:PLAYER_REGEN_DISABLED()
	if MacroForge.buttonEditMode then
		MacroForge:ToggleButtonEditMode(false)
	end

	if MacroForge.bindingMode then
		MacroForge:ToggleBindingMode(false)
	end

	if MacroForge.barEditMode then
		MacroForge:ToggleBarEditMode(false)
	end
end

function MacroForge:PLAYER_REGEN_ENABLED()
	if MacroForge.pendingStanceRefresh then
		MacroForge.pendingStanceRefresh = nil
		MacroForge:OnStanceMapUpdated()
	end
	MacroForge:RefreshActionButtonVisuals()
end

function MacroForge:OnTalentGroupChanged()
	for _, bar in pairs(MacroForge.bars) do
		if bar.class == "ActionBar" and bar.GetMultiSpec and bar:GetMultiSpec() and not InCombatLockdown() then
			for _, button in pairs(bar.buttons) do
				if button.UpdateButtonSpec then
					button:UpdateButtonSpec()
				end
			end
			bar:Load()
		end
	end
	MacroForge:UpdateSpellCache()
	MacroForge:UpdateStanceStrings()
	if MacroForge.buttonEditMode and MacroForge._guiLoaded and MacroForge.MacroForgeGUI and MacroForge.MacroForgeGUI.RefreshEditor then
		MacroForge.MacroForgeGUI:RefreshEditor("button")
	end
end

function MacroForge:RefreshActionButtonVisuals()
	for _, bar in pairs(MacroForge.bars) do
		if bar.class == "ActionBar" and bar.buttons then
			for _, button in pairs(bar.buttons) do
				local state = button.GetAttribute and button:GetAttribute("activestate")
				if (not state or state == "") and bar.handler then
					state = bar.handler:GetAttribute("activestate")
				end
				state = state or "homestate"
				state = tostring(state):match("([^:]+)$") or state
				if button.statedata and type(button.statedata[state]) == "table" then
					button.data = button.statedata[state]
				end
				if button.UpdateAll then
					button:UpdateAll()
				end
			end
		end
	end
end


function MacroForge:HookGameMenuFrame()
	local menuFrame = _G.GameMenuFrame
	if not menuFrame or type(menuFrame.SetScript) ~= "function" then
		return
	end
	if MacroForge:IsHooked(menuFrame, "OnUpdate") then
		return
	end
	MacroForge:HookScript(menuFrame, "OnUpdate", function(self)
		if MacroForge.barEditMode then
			HideUIPanel(self)
			MacroForge:ToggleBarEditMode(false)
		end

		if MacroForge.buttonEditMode then
			HideUIPanel(self)
			MacroForge:ToggleButtonEditMode(false)
		end

		if MacroForge.bindingMode then
			HideUIPanel(self)
			MacroForge:ToggleBindingMode(false)
		end
	end)
end

function MacroForge:PLAYER_ENTERING_WORLD()
	DB.firstRun = false

	MacroForge:HookGameMenuFrame()
	MacroForge:UpdateSpellCache()
	MacroForge:UpdateStanceStrings()

	--Fix for Titan causing the Main Bar to not be hidden
	if IsAddOnLoaded("Titan") then
		TitanUtils_AddonAdjust("MainMenuBar", true)
	end

	MacroForge:HideBlizzardUI(DB)
end

function MacroForge:ACTIVE_TALENT_GROUP_CHANGED()
	MacroForge:OnTalentGroupChanged()
end

function MacroForge:LEARNED_SPELL_IN_TAB()
	MacroForge:UpdateSpellCache()
	MacroForge:UpdateStanceStrings()
end

function MacroForge:CHARACTER_POINTS_CHANGED()
	MacroForge:UpdateSpellCache()
	MacroForge:UpdateStanceStrings()
end

function MacroForge:SPELLS_CHANGED()
	MacroForge:UpdateSpellCache()
	MacroForge:UpdateStanceStrings()
end

function MacroForge:UPDATE_SHAPESHIFT_FORMS()
	if InCombatLockdown() then
		MacroForge.pendingStanceRefresh = true
		return
	end
	MacroForge:OnStanceMapUpdated()
end

function MacroForge:UPDATE_SHAPESHIFT_FORM()
	-- Form swap only — refresh icons; do not rebuild stance map drivers.
	MacroForge:RefreshActionButtonVisuals()
end

-------------------------------------------------------------------------
--------------------Profiles---------------------------------------------
-------------------------------------------------------------------------


function MacroForge:RefreshConfig(db, profile)
	StaticPopup_Show("ReloadUI")
	MacroForge.pendingReload = true
end

-----------------------------------------------------------------


function MacroForge:LoginMessage()
	--displays a info window on login for either fresh installs or updates
	if not DB.updateWarning or DB.updateWarning ~= LATEST_VERSION_NUM  then
		if not IsAddOnLoaded("Masque") then
			print(" ")
			print("    Tip: Masque is optional and can skin MacroForge buttons if you want custom art.")
			print(" ")
		end
	end

	DB.updateWarning = LATEST_VERSION_NUM

	if Spec.active(true) > 4 then
		print(" ")
		MacroForge:Print("Warning: You do not currently have a specialization selected. Changes to any buttons which have 'Multi Spec' set will not persist.")
		print(" ")
	end

end

--- Load MacroForge_GUI (AceGUI + editor + Blizz options) on first use.
---@return boolean
function MacroForge:EnsureGUI()
	if MacroForge._guiLoaded and MacroForge.MacroForgeGUI then
		return true
	end
	if InCombatLockdown and InCombatLockdown() then
		MacroForge:Print("MacroForge editor cannot load during combat.")
		return false
	end

	local name = "MacroForge_GUI"
	if type(IsAddOnLoaded) == "function" and IsAddOnLoaded(name) then
		MacroForge._guiLoaded = true
		return MacroForge.MacroForgeGUI ~= nil
	end

	local loaded, reason
	if type(LoadAddOn) == "function" then
		loaded, reason = LoadAddOn(name)
	elseif type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
		loaded, reason = C_AddOns.LoadAddOn(name)
	else
		MacroForge:Print("MacroForge_GUI could not be loaded (LoadAddOn unavailable).")
		return false
	end

	if not loaded then
		MacroForge:Print("Failed to load MacroForge_GUI: " .. tostring(reason or "unknown")
			.. ". Ensure the MacroForge_GUI folder is installed next to MacroForge in Interface/AddOns.")
		return false
	end

	MacroForge._guiLoaded = true
	return MacroForge.MacroForgeGUI ~= nil
end



--- Creates a table containing provided data
-- @param index, bookType, spellName, altName, spellID, altSpellID, spellType, icon
-- @return curSpell:  Table containing provided data
function MacroForge:SetSpellInfo(index, bookType, spellType, spellName, spellID, icon, altName, altSpellID, altIcon)
	local curSpell = {}

	curSpell.index = index
	curSpell.booktype = bookType

	curSpell.spellType = spellType
	curSpell.spellName = spellName
	curSpell.spellID = spellID
	curSpell.icon = icon

	curSpell.altName = altName
	curSpell.altSpellID = altSpellID
	curSpell.altIcon = altIcon

	return curSpell
end

--- "()" indexes added because the Blizzard macro parser uses that to determine the difference of a spell versus a usable item if the two happen to have the same name.
--- I forgot this fact and removed using "()" and it made some macros not represent the right spell /sigh. This note is here so I do not forget again :P - Maul


--- Scans Character Spell Book and creates a table of all known spells.  This table is used to refrence macro spell info to generate tooltips and cooldowns.
---	If a spell is not displaying its tooltip or cooldown, then the spell in the macro probably is not in the database
function MacroForge:UpdateSpellCache()
	local sIndexMax = 0
	local numTabs = GetNumSpellTabs()

	for i=1,numTabs do
		local _, _, _, numSlots = GetSpellTabInfo(i)

		sIndexMax = sIndexMax + numSlots
	end

	for i = 1,sIndexMax do
		local spellName, _ = GetSpellBookItemName(i, BOOKTYPE_SPELL) --this returns the baseSpell name, even if it is augmented by talents. I.e. Roll and Chi Torpedo
		local spellType, spellID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
		local isPassive
		if spellName then
			isPassive = IsPassiveSpell(i, BOOKTYPE_SPELL)
		end
		local icon = GetSpellTexture(spellID)

		local altName
		local altSpellID
		local altIcon

		if (spellName and spellType ~= "FUTURESPELL") and not isPassive then

			-- Retail GetSpellInfo(name) can expose an alternate rank/ID; on 3.3.5 the
			-- seventh return is cast time (often 0), not a spell ID.
			if MacroForge.isWoWLegacy then
				altName = nil
				altSpellID = nil
				altIcon = nil
			else
				altName, _, altIcon, _, _, _, altSpellID = GetSpellInfo(spellName)

				if spellID == altSpellID then
					altSpellID = nil
					altName = nil
					altIcon = nil
				end
			end

			local spellData = MacroForge:SetSpellInfo(i, BOOKTYPE_SPELL, spellType, spellName, spellID, icon, altName, altSpellID, altIcon)

			MacroForge.spellCache[(spellName):lower()] = spellData
			MacroForge.spellCache[(spellName):lower().."()"] = spellData


			--reverse main and alt so we can put both in the table accurately
			local altSpellData = MacroForge:SetSpellInfo(i, BOOKTYPE_SPELL, spellType, altName, altSpellID, altIcon, spellName, spellID, icon)

			if altName and altName ~= spellName then
				MacroForge.spellCache[(altName):lower()] = altSpellData
				MacroForge.spellCache[(altName):lower().."()"] = altSpellData
			end

		end
	end

	if MacroForge.isWoWRetail then
		for i = 1, select("#", GetProfessions()) do
			local index = select(i, GetProfessions())

			if index then
				local _, _, _, _, numSpells, spelloffset = GetProfessionInfo(index)

				for j=1,numSpells do

					local offsetIndex = j + spelloffset
					local spellName, _ = GetSpellBookItemName(offsetIndex, BOOKTYPE_PROFESSION)
					local spellType, spellID = GetSpellBookItemInfo(offsetIndex, BOOKTYPE_PROFESSION)
					local icon

					if spellName and spellType ~= "FUTURESPELL" then
						icon = GetSpellTexture(spellID)
						local spellData = MacroForge:SetSpellInfo(offsetIndex, BOOKTYPE_PROFESSION, spellType, spellName, spellID, icon,nil,  nil, nil)

						MacroForge.spellCache[(spellName):lower()] = spellData
						MacroForge.spellCache[(spellName):lower().."()"] = spellData

					end
				end
			end
		end
	end
end

function MacroForge:ToggleMainMenu()
	if not MacroForge:EnsureGUI() then
		return
	end
	---need to run the command twice for some reason. The first one only seems to open the Interface panel
	if type(InterfaceOptionsFrame_OpenToCategory) == "function" then
		InterfaceOptionsFrame_OpenToCategory("MacroForge")
		InterfaceOptionsFrame_OpenToCategory("MacroForge")
	elseif Settings and Settings.OpenToCategory then
		Settings.OpenToCategory("MacroForge")
	end
end

function MacroForge:SelectFirstBar()
	if MacroForge.currentBar then
		return MacroForge.currentBar
	end
	for _, bar in ipairs(MacroForge.bars) do
		MacroForge.Bar.ChangeSelectedBar(bar)
		return bar
	end
	return nil
end

function MacroForge:EnsureBarsExist()
	if #MacroForge.bars > 0 then
		return
	end

	local empty = true
	for _, reg in pairs(MacroForge.registeredBarData) do
		for _, entry in pairs(reg.barDB) do
			if entry then
				empty = false
				break
			end
		end
		if not empty then
			break
		end
	end

	if empty then
		MacroForge:InitializeEmptyDatabase(DB)
	end

	MacroForge:CreateBarsAndButtons(DB)
	for _, bar in pairs(MacroForge.bars) do
		bar:Load()
	end
end

function MacroForge:ToggleBarEditMode(show)
	if show then
		MacroForge:EnsureBarsExist()
		MacroForge.barEditMode = true
		MacroForge:ToggleButtonEditMode(false)
		MacroForge:ToggleBindingMode(false)

		for _, bar in pairs(MacroForge.bars) do
			bar:PrepareForEditMode(false)
		end

		MacroForge:SelectFirstBar()
		if MacroForge.currentBar then
			MacroForge.currentBar:PrepareForEditMode(true)
		end
	else
		MacroForge.barEditMode = false
		for _, bar in pairs(MacroForge.bars) do
			local overlay = bar.editFrame
			bar.editFrame = nil
			if overlay then
				GetBarEditor().free(overlay)
			end

			bar:LeaveEditMode()
		end
	end
end

function MacroForge:ToggleButtonEditMode(show)
	local isActionBar = function(bar)
		return bar and bar.class == "ActionBar"
	end

	local bars = Array.filter(isActionBar, MacroForge.bars)

	if show then
		MacroForge.buttonEditMode = true

		MacroForge:ToggleBarEditMode(false)
		MacroForge:ToggleBindingMode(false)

		local currentButton =
			MacroForge.currentButton or
			(
				isActionBar(MacroForge.currentBar)
				and unpack(MacroForge.currentBar.buttons)
			) or
			Array.foldl(
				function(button, bar) return button or unpack(bar.buttons) end,
				nil,
				bars
			)

		if not currentButton then
			MacroForge.buttonEditMode = false
			return
		end

		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				button.editFrame = button.editFrame or ButtonEditor.allocate(
					button,
					"corners",
					function(btn)
						MacroForge.Button.ChangeSelectedButton(btn)
						if addonTable.MacroForgeEditor and MacroForge.MacroForgeGUI then
							MacroForge.MacroForgeGUI:RefreshEditor()
						end
					end
				)
			end

			bar:UpdateObjectVisibility(true)
			bar:UpdateBarStatus(true)
			bar:UpdateObjectStatus()
			bar:UpdateObjectUsability()
		end

		-- change the button, but also manually activate it
		-- just in case it was already the current button and
		-- so if the change is a noop, we still show the recticle
		MacroForge.Button.ChangeSelectedButton(currentButton)
		ButtonEditor.activate(currentButton.editFrame)
	else
		MacroForge.buttonEditMode = false

		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				if button.editFrame then
					ButtonEditor.free(button.editFrame)
					button.editFrame = nil
				end
			end

			bar:UpdateObjectVisibility()
			bar:UpdateBarStatus()
			bar:UpdateObjectStatus()
			bar:UpdateObjectUsability()
		end
	end
end

--- Processes the change to a key bind
--- @param targetButton Button
--- @param key string @The key to be used
local function processKeyBinding(targetButton, key)
	--if the button is locked, warn the user as to the locked status
	if targetButton.keys and targetButton.keys.hotKeyLock then
		UIErrorsFrame:AddMessage(L["Bindings_Locked_Notice"], 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME)
		return
	end

	--if the key being pressed is escape, clear the bindings on the button
	if key == "ESCAPE" then
		ClearOverrideBindings(targetButton)
		targetButton.keys.hotKeys = ":"
		targetButton:ApplyBindings()

		--if the key is anything else, keybind the button to this key
	elseif key then --checks to see if another keybind already has that key, and if so clears it from the other button
		--check to see if any other button has this key bound to it, ignoring locked buttons, and if so remove the key from the other button
		for _, bar in pairs(MacroForge.bars) do
			for _, button in pairs(bar.buttons) do
				if button.keys then
					if targetButton ~= button and not button.keys.hotKeyLock then
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
		end

		--search the current hotKeys to see if our new key is missing, and if so add it
		local found
		targetButton.keys.hotKeys:gsub("[^:]+", function(binding)
			if binding == key then
				found = true
			end
		end)

		if not found then
			targetButton.keys.hotKeys = targetButton.keys.hotKeys..key..":"
		end

		targetButton:ApplyBindings()
	end
end

function MacroForge:ToggleBindingMode(show)
	local isBindable = function(bar)
		return bar and (bar.class == "ActionBar" or bar.class == "PetBar")
	end

	local bars = Array.filter(isBindable, MacroForge.bars)

	if show then
		MacroForge.bindingMode = true
		MacroForge:ToggleButtonEditMode(false)
		MacroForge:ToggleBarEditMode(false)

		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				button.keybindFrame = button.keybindFrame or ButtonBinder.allocate(button, processKeyBinding)
			end

			bar:UpdateObjectVisibility(true)
			bar:UpdateBarStatus(true)
			bar:UpdateObjectStatus()
			bar:UpdateObjectUsability()
		end

	else
		MacroForge.bindingMode = false
		for _, bar in pairs(bars) do
			for _, button in pairs(bar.buttons) do
				if button.keybindFrame then
					ButtonBinder.free(button.keybindFrame)
					button.keybindFrame = nil
				end
			end
			bar:UpdateObjectVisibility()
			bar:UpdateBarStatus()
			bar:UpdateObjectStatus()
			bar:UpdateObjectUsability()
		end
	end
end

function MacroForge:GetSerializedAndCompressedProfile()
	local uncompressed = MacroForge:Serialize(MacroForge.db.profile) --serialize the database into a string value
	local compressed = LibDeflate:CompressZlib(uncompressed) --compress the data
	local encoded = LibDeflate:EncodeForPrint(compressed) --encode the data for print for copy+paste
	return encoded
end

function MacroForge:SetSerializedAndCompressedProfile(input)
	--check if the input is empty
	if input == "" then
		MacroForge:Print(L["No data to import."].." "..L["Aborting."])
		return
	end

	--decode and check if decoding worked properly
	local decoded = LibDeflate:DecodeForPrint(input)
	if decoded == nil then
		MacroForge:Print(L["Decoding failed."].." "..L["Aborting."])
		return
	end

	--uncompress and check if uncompresion worked properly
	local uncompressed = LibDeflate:DecompressZlib(decoded)
	if uncompressed == nil then
		MacroForge:Print(L["Decompression failed."].." "..L["Aborting."])
		return
	end

	--deserialize the data and return it back into a table format
	local result, newProfile = MacroForge:Deserialize(uncompressed)

	if result == true and newProfile then --if we successfully deserialize, load the new table and reload
		for k,v in pairs(newProfile) do
			if type(v) == "table" then
				MacroForge.db.profile[k] = CopyTable(v)
			else
				MacroForge.db.profile[k] = v
			end
		end
		ReloadUI()
	else
		MacroForge:Print(L["Data import Failed."].." "..L["Aborting."])
	end
end
