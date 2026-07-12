-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

-- LoadOnDemand companion: AceGUI + editor/options. Shares Neuron.package for GUI scripts.

local Neuron = LibStub("AceAddon-3.0"):GetAddon("Neuron")
local addonTable = Neuron.package

if not addonTable then
	error("Neuron_GUI: Neuron.package is missing; core Neuron must load first.")
end

-- Ensure AceGUI tooltip exists on this client (also patched in Neuron-Compat when present).
local AceGUI = LibStub("AceGUI-3.0", true)
if AceGUI and not AceGUI.tooltip then
	AceGUI.tooltip = CreateFrame("GameTooltip", "NeuronAceGUITooltip", UIParent, "GameTooltipTemplate")
end

Neuron.NeuronGUI = Neuron.NeuronGUI or {}

if Neuron.NeuronGUI.LoadInterfaceOptions then
	Neuron.NeuronGUI:LoadInterfaceOptions()
end

Neuron._guiLoaded = true
