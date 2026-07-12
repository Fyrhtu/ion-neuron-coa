-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

-- LoadOnDemand companion: AceGUI + editor/options. Shares MacroForge.package for GUI scripts.

local MacroForge = LibStub("AceAddon-3.0"):GetAddon("MacroForge")
local addonTable = MacroForge.package

if not addonTable then
	error("MacroForge_GUI: MacroForge.package is missing; core MacroForge must load first.")
end

-- Ensure AceGUI tooltip exists on this client (also patched in MacroForge-Compat when present).
local AceGUI = LibStub("AceGUI-3.0", true)
if AceGUI and not AceGUI.tooltip then
	AceGUI.tooltip = CreateFrame("GameTooltip", "MacroForgeAceGUITooltip", UIParent, "GameTooltipTemplate")
end

MacroForge.MacroForgeGUI = MacroForge.MacroForgeGUI or {}

if MacroForge.MacroForgeGUI.LoadInterfaceOptions then
	MacroForge.MacroForgeGUI:LoadInterfaceOptions()
end

MacroForge._guiLoaded = true
