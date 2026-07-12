-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local Neuron = addonTable.Neuron

local Array = addonTable.utilities.Array

addonTable.defaultProfile = {}

-----------------------------------
--------- Action Bar --------------
-----------------------------------
addonTable.defaultProfile.ActionBar = {
	[1] = {
		snapTo = false,
		snapToFrame = false,
		snapToPoint = false,
		point = "BOTTOM",
		x = 0,
		y = 55,
		showGrid = true,
		multiSpec = true,
		vehicle = not Neuron.isWoWLegacy,
		possess = not Neuron.isWoWLegacy,
		dragonriding = not Neuron.isWoWLegacy,
		override = not Neuron.isWoWLegacy,

		buttons = Array.map(
			function(key) return { keys = { hotKeys = key}, } end,
			{ ":1:", ":2:", ":3:", ":4:", ":5:", ":6:", ":7:", ":8:", ":9:", ":0:", ":-:", ":=:",}
		),
	},

	[2] = {
		snapTo = false,
		snapToFrame = false,
		snapToPoint = false,
		point = "BOTTOM",
		x = 0,
		y = 100,
		showGrid = true,

		buttons = Array.initialize(12, function() return {} end),
	}
}

-----------------------------------
------------ Pet Bar --------------
-----------------------------------
addonTable.defaultProfile.PetBar = {
	[1] = {
		hidestates = ":pet0:",
		showGrid = true,
		scale = 0.8,
		snapTo = false,
		snapToFrame = false,
		snapToPoint = false,
		point = "BOTTOM",
		x = -500,
		y = 75,

		buttons = Array.initialize(10, function() return {} end),
	}
}
