-- MacroForge is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local MacroForge = addonTable.MacroForge

local L = LibStub("AceLocale-3.0"):GetLocale("MacroForge")

function MacroForge:RegisterBars(DB)
  -- CoA lite: Action bars + optional pet bar only.
  -- Cast/Mirror/XP/Rep, Bag/Menu, and retail Extra/Zone/Exit are not registered.
  local allBars = {
    ActionBar = {
      class = "ActionBar",
      barType = "ActionBar",
      barLabel = L["Action Bar"],
      objType = "ActionButton",
      barDB = DB.ActionBar,
      objTemplate = MacroForge.ActionButton,
      objMax = 250
    },
    PetBar = {
      class = "PetBar",
      barType = "PetBar",
      barLabel = L["Pet Bar"],
      objType = "PetButton",
      barDB = DB.PetBar,
      objTemplate = MacroForge.PetButton,
      objMax = 10
    },
  }

  return allBars
end
