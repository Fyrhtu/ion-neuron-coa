-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local MacroForge = LibStub("AceAddon-3.0"):GetAddon("MacroForge")
local addonTable = MacroForge.package

function MacroForge:RegisterGUI()
	local allBars = {
		ActionBar = {
			class = "ActionBar",
			generalOptions = {
				AUTOHIDE = true,
				SHOWGRID = true,
				SNAPTO = true,
				CLICKMODE = true,
				MULTISPEC = true,
				HIDDEN = true,
				LOCKBAR = true,
			},
			visualOptions = {
				BINDTEXT = true,
				BUTTONTEXT = true,
				COUNTTEXT = true,
				RANGEIND = true,
				CDTEXT = true,
				CDALPHA = true,
				SPELLGLOW = not MacroForge.isWoWLegacy,
				TOOLTIPS = true,
			}
		},
		PetBar = {
			class = "PetBar",
			generalOptions = {
				AUTOHIDE  = true,
				SNAPTO    = true,
				CLICKMODE = true,
				HIDDEN    = true,
				LOCKBAR   = true,
			},
			visualOptions = {
				BINDTEXT = true,
				BUTTONTEXT = true,
				RANGEIND = true,
				CDTEXT = true,
				CDALPHA = true,
				TOOLTIPS = true,
			}
		},
	}
	return allBars
end
