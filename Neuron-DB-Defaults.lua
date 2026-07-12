-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...

---**NOTE** values assigned with empty quotes, i.e. name = "", basically don't exist. Lua treats them as nil

local genericButtonData = {
	btnType = "macro",
}


---@class GenericSpecData
---@field actionID number|false|nil
---@field macro_Text string
---@field macro_Icon number|string|false
---@field macro_Name string
---@field macro_Note string
---@field macro_UseNote false
---@field macro_BlizzMacro string|false
---@field macro_EquipmentSet any|false

---@type GenericSpecData
local genericSpecData = {
	actionID = false,

	macro_Text = "",
	macro_Icon = false,
	macro_Name = "",
    macro_Note = "",
	macro_UseNote = false,
    macro_BlizzMacro = false,
	macro_EquipmentSet = false,
}

local genericKeyData = {
	hotKeyLock = false,
	hotKeyPri = false,
	hotKeys = ":"
}


local genericBarData = {
	name = ":",

	buttons = {
		['*'] = {
			['config'] = CopyTable(genericButtonData),
			['keys'] = CopyTable(genericKeyData),
			['data'] = {},
		}
	},

	hidestates = ":",

	point = "BOTTOM",
	x = 0,
	y = 190,

	scale = 1,
	shape = "linear",
	columns = 0,

	alpha = 1,
	alphaUp = "off",
	alphaMax = 1,
	fadeSpeed = 0.5,

	strata = 3,

	padH = 3,
	padV = 3,
	arcStart = 0,
	arcLength = 359,

	snapTo = false,
	snapToPad = 0,
	snapToPoint = false,
	snapToFrame = false,

	autoHide = false,
	showGrid = true,

	bindColor = {1,1,1},
	macroColor = {1,1,1},
	countColor = {1,1,1},
	cdcolor1 = {1,0.82,0},
	cdcolor2 = {1,0.1,0.1},
	rangecolor = {0.7,0.15,0.15},
	manacolor = {0.5,0.5,1.0},

	border = true,

	clickMode = "UpClick",

	conceal = false,

	multiSpec = false,

	spellGlow = "default",

	barLock = false,

	tooltips = "normal",
	tooltipsCombat = true,

	bindText = true,
	buttonText = true,
	countText = true,
	rangeInd = true,

	cdText = false,
	cdAlpha = false,

	showBorderStyle = true,

	homestate = true,
	paged = false,
	stance = false,
	stealth = false,
	reaction = false,
	combat = false,
	group = false,
	pet = false,
	fishing = false,
	vehicle = false,
	possess = false,
	dragonriding = false,
	override = false,
	extrabar = false,
	alt = false,
	ctrl = false,
	shift = false,
	target = false,

	selfCast = false,
	focusCast = false,
	rightClickTarget = false,
	mouseOverCast = false,

	custom = false,
	customRange = false,
	customNames = false,

	remap = false,
}



------------------------------------------------------------------------
----------------------MAIN TABLE----------------------------------------
------------------------------------------------------------------------

-- CoA lite: only ActionBar + PetBar. Cast/Mirror/XP/Rep and Bag/Menu/Exit/Extra/Zone removed.
addonTable.databaseDefaults = {
	profile = {
		blizzBars = {
			-- ActionBar is special: showing blizz action bars doesn't hide neuron action bars
			ActionBar = false,
			PetBar = false,
		},

		mouseOverMod= "NONE",

		firstRun = true,

		NeuronItemCache = {},
		NeuronSpellCache = {},

		NeuronIcon = {hide = false},

		ActionBar = {
			['*'] = CopyTable(genericBarData)
		},

		PetBar = {
			['*'] = CopyTable(genericBarData)
		},
	}
}

------------------------------------------------------------------------------


addonTable.databaseDefaults.profile.ActionBar['*'].buttons = {
	['*'] = {
		['config'] = CopyTable(genericButtonData),
		['keys'] = CopyTable(genericKeyData),
		[1] = {['**'] = CopyTable(genericSpecData), ['homestate'] = {}},
		[2] = {['**'] = CopyTable(genericSpecData), ['homestate'] = {}},
		[3] = {['**'] = CopyTable(genericSpecData), ['homestate'] = {}},
		[4] = {['**'] = CopyTable(genericSpecData), ['homestate'] = {}},
		--any time a player is without spec, it is not treated as spec 5
		[5] = {['**'] = CopyTable(genericSpecData), ['homestate'] = {}}, --we need this or we will error out on new character creation
	}
}
