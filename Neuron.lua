-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)


local _, addonTable = ...

local Spec = addonTable.utilities.Spec
local DBFixer = addonTable.utilities.DBFixer
local Array = addonTable.utilities.Array
local ButtonBinder = addonTable.overlay.ButtonBinder
local ButtonEditor = addonTable.overlay.ButtonEditor

local function GetBarEditor()
	return addonTable.overlay.BarEditor
end

---@class Neuron : AceAddon-3.0 @define The main addon object for the Neuron Action Bar addon
addonTable.Neuron = LibStub("AceAddon-3.0"):NewAddon(CreateFrame("Frame", nil, UIParent), "Neuron", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0", "AceSerializer-3.0")
local Neuron = addonTable.Neuron

local DB

local LibDeflate = LibStub:GetLibrary("LibDeflate")
local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")

local LATEST_VERSION_NUM = "1.4.25-CoA" --this variable is set to popup a welcome message upon updating/installing. Only change it if you want to pop up a message after the users next update

--prepare the Neuron table with some sub-tables that will be used down the road
Neuron.bars = {} --this table will be our main handle for all of our bars.

Neuron.registeredBarData = {}

--these are the database tables that are going to hold our data. They are global because every .lua file needs access to them
Neuron.itemCache = {} --Stores a cache of all items that have been seen by a Neuron button
Neuron.spellCache = {} --Stores a cache of all spells that have been seen by a Neuron button

Neuron.barEditMode = false
Neuron.buttonEditMode = false
Neuron.bindingMode = false

-- Ascension CoA uses a 3.3.5 client that may report WOW_PROJECT_MAINLINE without retail APIs.
local _, _, _, interfaceVersion = GetBuildInfo()
interfaceVersion = tonumber(interfaceVersion) or 99999
local hasRetailAPIs = type(GetNumSpecializationsForClassID) == "function"
	and type(GetProfessions) == "function"

Neuron.isWoWLegacy = not hasRetailAPIs or interfaceVersion <= 30300
Neuron.isWoWClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
Neuron.isWoWWrathClassic = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
Neuron.isWoWRetail = hasRetailAPIs and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
Neuron.isWoWWotLK = Neuron.isWoWWrathClassic or Neuron.isWoWLegacy or not hasRetailAPIs
Neuron.isAscensionCoA = Neuron.isWoWLegacy

Neuron.STRATAS = {
	[1] = "BACKGROUND",
	[2] = "LOW",
	[3] = "MEDIUM",
	[4] = "HIGH",
	[5] = "DIALOG",
	[6] = "TOOLTIP"
}

Neuron.TIMERLIMIT = 4
Neuron.SNAPTO_TOLERANCE = 28

Neuron.DEBUG = true

-------------------------------------------------------------------------
--------------------Start of Functions-----------------------------------
-------------------------------------------------------------------------

--- **OnInitialize**, which is called directly after the addon is fully loaded.
--- do init tasks here, like loading the Saved Variables
--- or setting up slash commands.
function Neuron:OnInitialize()
	Neuron.db = LibStub("AceDB-3.0"):New("NeuronProfilesDB", addonTable.databaseDefaults)

	--Check if the current database needs to be migrated, and attempt the migration
	Neuron.db = DBFixer.databaseMigration(Neuron.db)
	DB = Neuron.db.profile

	Neuron.db.RegisterCallback(Neuron, "OnProfileChanged", "RefreshConfig")
	Neuron.db.RegisterCallback(Neuron, "OnProfileCopied", "RefreshConfig")
	Neuron.db.RegisterCallback(Neuron, "OnProfileReset", "RefreshConfig")
	Neuron.db.RegisterCallback(Neuron, "OnDatabaseReset", "RefreshConfig")

	--load saved variables into working variable containers
	Neuron.itemCache = DB.NeuronItemCache
	Neuron.spellCache = DB.NeuronSpellCache

	Neuron.class = select(2, UnitClass("player"))
	Neuron:UpdateStanceStrings()

	StaticPopupDialogs["ReloadUI"] = {
		text = L["ReloadUI"],
		button1 = OKAY,
		OnAccept = function()
			ReloadUI()
		end,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}

	--Initialize the Minimap Icon
	Neuron:Minimap_IconInitialize()

	--Initialize the chat commands (i.e. /neuron)
	--Neuron:RegisterChatCommand("neuron", "slashHandler")

	--build all bar and button frames and run initial setup
	Neuron.registeredBarData = Neuron:RegisterBars(DB)
	if DB.firstRun then
		Neuron:InitializeEmptyDatabase(DB)
	end
	Neuron:CreateBarsAndButtons(DB)
end

--- **OnEnable** which gets called during the PLAYER_LOGIN event, when most of the data provided by the game is already present.
--- Do more initialization here, that really enables the use of your addon.
--- Register Events, Hook functions, Create Frames, Get information from
--- the game that wasn't available in OnInitialize
function Neuron:OnEnable()
	if Neuron.DEBUG then
		_G.Neuron = Neuron
	end

	Neuron:RegisterEvent("PLAYER_REGEN_DISABLED")
	Neuron:RegisterEvent("PLAYER_REGEN_ENABLED")
	Neuron:RegisterEvent("PLAYER_ENTERING_WORLD")
	Neuron:RegisterEvent("SPELLS_CHANGED")
	Neuron:RegisterEvent("CHARACTER_POINTS_CHANGED")
	Neuron:RegisterEvent("LEARNED_SPELL_IN_TAB")
	Neuron:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	Neuron:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

	-- Multi-spec (Ascension Character Advancement specializations)
	if type(SpecializationUtil) == "table" and type(SpecializationUtil.GetActiveSpecialization) == "function" then
		Neuron:RegisterEvent("ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "OnTalentGroupChanged")
	end
	if Neuron.isWoWRetail or Neuron.isWoWWotLK or Neuron.isAscensionCoA then
		Neuron:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnTalentGroupChanged")
		Neuron:RegisterEvent("PLAYER_TALENT_UPDATE", "OnTalentGroupChanged")
	end

	Neuron:UpdateStanceStrings()

	--this allows for the "Esc" key to disable the Edit Mode instead of bringing up the game menu, but only if an edit mode is activated.

	Neuron:HookGameMenuFrame()

	Neuron:LoginMessage()

	--Load all bars and buttons
	for _,v in pairs(Neuron.bars) do
		v:Load()
	end

	--this is a hack for 10.0. They broke everything with regard to the way addons interface with
	--SecureActionButtons see SecureTemplates.lua SecureActionButton_OnClick() for more information
	if Neuron.isWoWRetail and GetCVar and GetCVar("ActionButtonUseKeyDown") then
		SetCVar("ActionButtonUseKeyDown", 0)
	end

	Neuron.NeuronGUI:LoadInterfaceOptions()

end

--- **OnDisable**, which is only called when your addon is manually being disabled.
--- Unhook, Unregister Events, Hide frames that you created.
--- You would probably only use an OnDisable if you want to
--- build a "standby" mode, or be able to toggle modules on/off.
function Neuron:OnDisable()
	if Neuron.isWoWRetail and GetCVar and GetCVar("ActionButtonUseKeyDown") then
		SetCVar("ActionButtonUseKeyDown", 1)
	end
end

-------------------------------------------------

function Neuron:PLAYER_REGEN_DISABLED()
	if Neuron.buttonEditMode then
		Neuron:ToggleButtonEditMode(false)
	end

	if Neuron.bindingMode then
		Neuron:ToggleBindingMode(false)
	end

	if Neuron.barEditMode then
		Neuron:ToggleBarEditMode(false)
	end
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
				if button.UpdateButtonSpec then
					button:UpdateButtonSpec()
				end
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


function Neuron:HookGameMenuFrame()
	local menuFrame = _G.GameMenuFrame
	if not menuFrame or type(menuFrame.SetScript) ~= "function" then
		return
	end
	if Neuron:IsHooked(menuFrame, "OnUpdate") then
		return
	end
	Neuron:HookScript(menuFrame, "OnUpdate", function(self)
		if Neuron.barEditMode then
			HideUIPanel(self)
			Neuron:ToggleBarEditMode(false)
		end

		if Neuron.buttonEditMode then
			HideUIPanel(self)
			Neuron:ToggleButtonEditMode(false)
		end

		if Neuron.bindingMode then
			HideUIPanel(self)
			Neuron:ToggleBindingMode(false)
		end
	end)
end

function Neuron:PLAYER_ENTERING_WORLD()
	DB.firstRun = false

	Neuron:HookGameMenuFrame()
	Neuron:UpdateSpellCache()
	Neuron:UpdateStanceStrings()

	--Fix for Titan causing the Main Bar to not be hidden
	if IsAddOnLoaded("Titan") then
		TitanUtils_AddonAdjust("MainMenuBar", true)
	end

	Neuron:HideBlizzardUI(DB)
end

function Neuron:ACTIVE_TALENT_GROUP_CHANGED()
	Neuron:OnTalentGroupChanged()
end

function Neuron:LEARNED_SPELL_IN_TAB()
	Neuron:UpdateSpellCache()
	Neuron:UpdateStanceStrings()
end

function Neuron:CHARACTER_POINTS_CHANGED()
	Neuron:UpdateSpellCache()
	Neuron:UpdateStanceStrings()
end

function Neuron:SPELLS_CHANGED()
	Neuron:UpdateSpellCache()
	Neuron:UpdateStanceStrings()
end

function Neuron:UPDATE_SHAPESHIFT_FORMS()
	if InCombatLockdown() then
		Neuron.pendingStanceRefresh = true
		return
	end
	Neuron:OnStanceMapUpdated()
end

function Neuron:UPDATE_SHAPESHIFT_FORM()
	-- Form swap only — refresh icons; do not rebuild stance map drivers.
	Neuron:RefreshActionButtonVisuals()
end

-------------------------------------------------------------------------
--------------------Profiles---------------------------------------------
-------------------------------------------------------------------------


function Neuron:RefreshConfig(db, profile)
	StaticPopup_Show("ReloadUI")
	Neuron.pendingReload = true
end

-----------------------------------------------------------------


function Neuron:LoginMessage()
	--displays a info window on login for either fresh installs or updates
	if not DB.updateWarning or DB.updateWarning ~= LATEST_VERSION_NUM  then
		if not IsAddOnLoaded("Masque") then
			print(" ")
			print("    You do not currently have Masque installed or enabled.")
			print("    Please consider using Masque for enhancing the visual appearance of Neuron's action buttons.")
			print("    We recommend using Masque: Neuron, the theme made by Soyier for use with Neuron.")
			print(" ")
		end
	end

	DB.updateWarning = LATEST_VERSION_NUM

	if Spec.active(true) > 4 then
		print(" ")
		Neuron:Print("Warning: You do not currently have a specialization selected. Changes to any buttons which have 'Multi Spec' set will not persist.")
		print(" ")
	end

	--Shadowlands warning that will show as long as a player has one button on their ZoneAbilityBar for Shadowlands content
	if Neuron.isWoWRetail and UnitLevel("player") >= 50 and Neuron.db.profile.ZoneAbilityBar[1] and #Neuron.db.profile.ZoneAbilityBar[1].buttons == 1 then
		print(" ")
		Neuron:Print(WrapTextInColorCode("IMPORTANT: Shadowlands content now requires multiple Zone Ability Buttons. Please add at least 3 buttons to your Zone Ability Bar to support this new functionality.", "FF00FFEC"))
		print(" ")
	end
end
