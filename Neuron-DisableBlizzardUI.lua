-- Neuron is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2023 Britt W. Yazel
-- Copyright (c) 2006-2014 Connor H. Chenoweth
-- This code is licensed under the MIT license (see LICENSE for details)

local _, addonTable = ...
local Neuron = addonTable.Neuron

-- Hidden parent frame
local UIHider = CreateFrame("Frame")
UIHider:Hide()


local function disableBarFrame(frame)
	if frame then
		frame:UnregisterAllEvents()
		frame:SetParent(UIHider)
		frame:Hide()
	end
end

local function disableButtonFrame(frame)
	if frame then
		frame:UnregisterAllEvents()
		frame:SetAttribute("statehidden", true)
		frame:Hide()
	end
end

local function disableFrameSlidingAnimation(frame)
	if frame and frame.slideOut then
		local animation = {frame.slideOut:GetAnimations()}
		animation[1]:SetOffset(0,0)
	end
end

function Neuron:HideBlizzardUI(profileDatabase)
	local blizzBars = profileDatabase.blizzBars
	----------------------------
	----- Disable Buttons ------
	----------------------------
	--Hide and disable the individual buttons on most of our bars
	if not blizzBars.ActionBar then
		for i=1,12 do
			disableButtonFrame(_G["ActionButton"..i])
			disableButtonFrame(_G["MultiBarBottomLeftButton"..i])
			disableButtonFrame(_G["MultiBarBottomRightButton"..i])
			disableButtonFrame(_G["MultiBarRightButton"..i])
			disableButtonFrame(_G["MultiBarLeftButton"..i])
		end

		for i=1,6 do
			disableButtonFrame(_G["OverrideActionBarButton"..i])
		end

		--disable main blizzard bar and graphics
		disableBarFrame(MainMenuBar)
		disableBarFrame(MainMenuBarArtFrame)
		disableBarFrame(MainMenuBarArtFrameBackground)
		disableFrameSlidingAnimation(MainMenuBar)

		--disable bottom bonus bars
		disableBarFrame(MultiBarBottomLeft)
		disableBarFrame(MultiBarBottomRight)

		--disable side bonus bars
		disableBarFrame(MultiBarLeft)
		disableBarFrame(MultiBarRight)
		disableBarFrame(MultiBar5)
		disableBarFrame(MultiBar6)
		disableBarFrame(MultiBar7)

		disableBarFrame(StanceBar)
		disableBarFrame(StanceBarFrame)
		disableBarFrame(PossessBar)
		disableBarFrame(PossessBarFrame)


		disableBarFrame(OverrideActionBar)
		disableFrameSlidingAnimation(OverrideActionBar)

		-- i think this is the shaman bar, it seems like it was deprecated in cata
		-- just leave it on always https://github.com/brittyazel/Neuron/issues/444
		-- disableBarFrame(MultiCastActionBarFrame)

		--disable the ActionBarController to avoid potential for taint
		if ActionBarController then
			ActionBarController:UnregisterAllEvents()
		end

		--these two get called when opening the spellbook so it's best to just silence them ahead of time
		if not Neuron:IsHooked("MultiActionBar_ShowAllGrids") then
			Neuron:RawHook("MultiActionBar_ShowAllGrids", function() end, true)
		end
		if not Neuron:IsHooked("MultiActionBar_HideAllGrids") then
			Neuron:RawHook("MultiActionBar_HideAllGrids", function() end, true)
		end
	end

	-- Cast/Mirror/XP/Rep and bag/menu/exit/extra/zone are no longer managed by Neuron.
	-- Leave standard UI (or other addons) in control of those frames.

	if not blizzBars.PetBar then
		disableBarFrame(PetActionBar)
		disableBarFrame(PetActionBarFrame)
	end

	----------------------------
	----- Disable Tutorial -----
	----------------------------
	--it's important we shut down the tutorial or we will get a ton of errors
	--this cleanly shuts down the tutorial and returns visibility to all UI elements hidden
	if Tutorials then --the Tutorials table is only available during the tutorial scenario, ignore if otherwise
		Tutorials:Shutdown()
	end
end

function Neuron:ToggleBlizzUI(blizzBars)
	if InCombatLockdown() then
		return
	end

	if blizzBars then
		local DB = Neuron.db.profile
		DB.blizzBars = CopyTable(DB.blizzBars)
		MergeTable(DB.blizzBars, blizzBars)
	end
end
