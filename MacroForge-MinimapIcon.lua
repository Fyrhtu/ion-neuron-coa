-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local MacroForge = addonTable.MacroForge

--MacroForge MinimapIcon makes use of LibDBIcon and LibDataBroker to make sure we play
--nicely with LDB addons and to simplify dramatically the minimap button

local L = LibStub("AceLocale-3.0"):GetLocale("MacroForge")

local DB
local macroForgeIconLDB
local icon

-------------------------------------------------------------------------
-------------------------------------------------------------------------
function MacroForge:Minimap_IconInitialize()
	DB = MacroForge.db.profile

	-- retail-only addon compartment button
	if MacroForge.isWoWRetail and DB.MacroForgeIcon then
		DB.MacroForgeIcon.showInCompartment = true
	end

	macroForgeIconLDB = LibStub("LibDataBroker-1.1"):NewDataObject("MacroForge", {
		type = "launcher",
		text = "MacroForge",
		icon = "Interface\\AddOns\\MacroForge\\Images\\static_icon",
		OnClick = function(_, button) MacroForge:Minimap_OnClickHandler(button) end,
		OnTooltipShow = function(tooltip) MacroForge:Minimap_TooltipHandler(tooltip) end,
	})

	icon = LibStub("LibDBIcon-1.0")
	icon:Register("MacroForge", macroForgeIconLDB, DB.MacroForgeIcon)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function playClickSound()
	if SOUNDKIT and SOUNDKIT.IG_CHAT_SCROLL_DOWN then
		pcall(PlaySound, SOUNDKIT.IG_CHAT_SCROLL_DOWN)
	elseif PlaySound then
		pcall(PlaySound, "igMainMenuOptionCheckBoxOn")
	end
end

function MacroForge:Minimap_OnClickHandler(button)
	if InCombatLockdown() then
		return
	end

	playClickSound()

	if button == "LeftButton" then
		if IsShiftKeyDown() then
			if not MacroForge.bindingMode then
				MacroForge:ToggleBindingMode(true)
			else
				MacroForge:ToggleBindingMode(false)
			end
		else
			if not MacroForge:EnsureGUI() then
				return
			end
			if not MacroForge.barEditMode then
				MacroForge:ToggleBarEditMode(true)
				if not addonTable.MacroForgeEditor then
					MacroForge.MacroForgeGUI:CreateEditor("bar")
				else
					MacroForge.MacroForgeGUI:RefreshEditor("bar")
				end
			elseif addonTable.MacroForgeEditor then
				MacroForge:ToggleBarEditMode(false)
				MacroForge.MacroForgeGUI:DestroyEditor()
			else
				-- Bar edit mode is on but the editor was closed; reopen it.
				MacroForge.MacroForgeGUI:CreateEditor("bar")
			end
		end
	elseif button == "RightButton" then
		if IsShiftKeyDown() then
			if SettingsPanel and SettingsPanel:IsShown() then
				SettingsPanel:Hide()
			elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then --this is for pre-dragonflight compatibility
				InterfaceOptionsFrame:Hide();
			else
				MacroForge:ToggleMainMenu()
			end
		else
			if not MacroForge:EnsureGUI() then
				return
			end
			if not MacroForge.buttonEditMode then
				MacroForge:ToggleButtonEditMode(true)
				if not addonTable.MacroForgeEditor then
					MacroForge.MacroForgeGUI:CreateEditor("button")
				else
					MacroForge.MacroForgeGUI:RefreshEditor("button")
				end
			elseif addonTable.MacroForgeEditor then
				MacroForge:ToggleButtonEditMode(false)
				MacroForge.MacroForgeGUI:DestroyEditor()
			else
				MacroForge.MacroForgeGUI:CreateEditor("button")
			end
		end
	end
end

function MacroForge:Minimap_TooltipHandler(tooltip)
	tooltip:SetText("MacroForge", 1, 1, 1)
	--the formatting for the following strings is such that the key combo is in yellow, and the description is in white. This helps it be more readable at a glance
	--another route would be to use AddDoubleLine, to have a left justified string and a right justified string on the same line
	tooltip:AddLine(L["Left-Click"] .. ": " .. "|cFFFFFFFF"..L["Configure Bars"])
	tooltip:AddLine(L["Right-Click"] .. ": " .. "|cFFFFFFFF"..L["Configure Buttons"])
	tooltip:AddLine(L["Shift"] .. " + " .. L["Left-Click"] .. ": " .. "|cFFFFFFFF"..L["Toggle Keybind Mode"])
	tooltip:AddLine(L["Shift"] .. " + " .. L["Right-Click"] .. ": " .. "|cFFFFFFFF"..L["Open the Interface Menu"])

	tooltip:Show()
end

function MacroForge:Minimap_ToggleIcon()
	if DB.MacroForgeIcon.hide == false then
		icon:Hide("MacroForge")
		DB.MacroForgeIcon.hide = true
	elseif DB.MacroForgeIcon.hide == true then
		icon:Show("MacroForge")
		DB.MacroForgeIcon.hide = false
	end
end