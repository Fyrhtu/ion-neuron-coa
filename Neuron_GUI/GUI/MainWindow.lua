-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local Neuron = LibStub("AceAddon-3.0"):GetAddon("Neuron")
local addonTable = Neuron.package
-- was: local _, addonTable = ...

Neuron.NeuronGUI = Neuron.NeuronGUI or {}
local NeuronGUI = Neuron.NeuronGUI

local L = LibStub("AceLocale-3.0"):GetLocale("Neuron")
local AceGUI = LibStub("AceGUI-3.0")

local Array = addonTable.utilities.Array

local currentTab = "bar" --remember which tab we were using between refreshes

local EDITOR_MIN_WIDTH = 760
local EDITOR_MIN_HEIGHT = 520

local function getEditorDimensions()
	local screenW = UIParent:GetWidth() or GetScreenWidth()
	local screenH = UIParent:GetHeight() or GetScreenHeight()
	local width = math.floor(math.min(920, math.max(EDITOR_MIN_WIDTH, screenW * 0.68)))
	local height = math.floor(math.min(780, math.max(620, screenH * 0.70)))
	return width, height
end

local function applyEditorSize(editor)
	if not editor then
		return
	end
	local width, height = getEditorDimensions()
	editor:SetWidth(width)
	editor:SetHeight(height)
	if editor.frame then
		editor.frame:SetWidth(width)
		editor.frame:SetHeight(height)
		if editor.content then
			editor.content:SetWidth(width - 34)
			editor.content:SetHeight(height - 57)
		end
	end
	if editor.DoLayout then
		editor:DoLayout()
	end
end

-----------------------------------------------------------------------------
--------------------------Main Window----------------------------------------
-----------------------------------------------------------------------------

function NeuronGUI:RefreshEditor(defaultTab)
	addonTable.NeuronEditor:ReleaseChildren()

	if defaultTab then
		currentTab = defaultTab
	end

	--re-add all the stuff to the editor window
	NeuronGUI:PopulateEditorWindow()

	if Neuron.currentBar then
		addonTable.NeuronEditor:SetStatusText("|cffffd200" .. Neuron.currentBar:GetBarName().."|cFFFFFFFF is currently selected. Left-click a different bar to change your selection.")
	else
		addonTable.NeuronEditor:SetStatusText("|cFFFFFFFFWelcome to the Neuron editor, please select a bar to begin")
	end
end


function NeuronGUI:CreateEditor(defaultTab)
	addonTable.NeuronEditor = AceGUI:Create("Frame") --add it to our base addon table to reference later

	addonTable.NeuronEditor:SetTitle("Neuron Editor")
	addonTable.NeuronEditor:EnableResize(true)
	if addonTable.NeuronEditor.frame.SetResizeBounds then -- WoW 10.0
		addonTable.NeuronEditor.frame:SetResizeBounds(EDITOR_MIN_WIDTH, EDITOR_MIN_HEIGHT)
	else
		addonTable.NeuronEditor.frame:SetMinResize(EDITOR_MIN_WIDTH, EDITOR_MIN_HEIGHT)
	end
	applyEditorSize(addonTable.NeuronEditor)
	if Neuron.currentBar then
		addonTable.NeuronEditor:SetStatusText("|cffffd200" .. Neuron.currentBar:GetBarName().."|cFFFFFFFF is currently selected. Left-click a different bar to change your selection.")
	else
		addonTable.NeuronEditor:SetStatusText("|cFFFFFFFFWelcome to the Neuron editor, please select a bar to begin")
	end
	addonTable.NeuronEditor:SetCallback("OnClose", function() NeuronGUI:DestroyEditor() end)
	addonTable.NeuronEditor:SetLayout("Fill")

	-- make the thing closable with escape
	_G.NeuronEditorMainFrame = addonTable.NeuronEditor
	tinsert(UISpecialFrames, "NeuronEditorMainFrame")

	if defaultTab then
		currentTab = defaultTab
	end
	--add all the stuff to the editor window
	NeuronGUI:PopulateEditorWindow()
	applyEditorSize(addonTable.NeuronEditor)
end

function NeuronGUI:DestroyEditor()
	if addonTable.NeuronEditor then
		AceGUI:Release(addonTable.NeuronEditor)
		addonTable.NeuronEditor = nil
	end

	if Neuron.barEditMode and addonTable.overlay and addonTable.overlay.BarEditor then
		addonTable.overlay.BarEditor.syncAll()
	end
end

function NeuronGUI:PopulateEditorWindow()
	Neuron:EnsureBarsExist()
	Neuron:SelectFirstBar()

	local bar = Neuron.currentBar
	local tabs = {{text="Bar Settings", value="bar"}}
	if bar and bar.barType == "ActionBar" then
		-- only action bars have editable buttons
		table.insert(tabs, {text=L["Configure Buttons"], value="button"})
	end

	-- make sure that we switch to the bar tab
	-- when selecting a bar without the current tab
	currentTab = Array.foldl(
		function(current, candidate)
			return candidate.value == currentTab and currentTab or current
		end,
		"bar",
		tabs
	)

	--Tab group that will contain all of our settings to configure
	local tabFrame = AceGUI:Create("TabGroup")
	tabFrame:SetLayout("Fill")
	tabFrame:SetFullWidth(true)
	tabFrame:SetFullHeight(true)
	tabFrame:SetTabs(tabs)
	tabFrame:SetCallback("OnGroupSelected", function(frame, _, value) NeuronGUI:SelectTab(frame, _, value) end)
	addonTable.NeuronEditor:AddChild(tabFrame)
	tabFrame:SelectTab(currentTab)
	-- AceGUI TabGroup does not always fire OnGroupSelected on programmatic SelectTab (3.3.5).
	NeuronGUI:SelectTab(tabFrame, nil, currentTab)
end


function NeuronGUI:SelectTab(tabFrame, _, value)
	tabFrame:ReleaseChildren()
	if value == "bar" then
		NeuronGUI:BarEditPanel(tabFrame)
	elseif value == "button" then
		-- whenever we change a button, RefreshEditor is called upstream
		-- so we don't need to keep track of updating currentButton here
		NeuronGUI:ButtonsEditPanel(tabFrame)
	else
		return -- if we get here we forgot to add a tab!
	end
	currentTab = value
end
