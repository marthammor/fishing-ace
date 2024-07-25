--[[
Fishing Ace!
Copyright (c) by Bob Schumaker
Licensed under a Creative Commons "Attribution Non-Commercial Share Alike" License
]] --

local L = LibStub("AceLocale-3.0"):GetLocale("FishingAce", true)
local FL = LibStub("LibFishing-1.0")

local ADDONNAME = "Fishing Ace!"

local db;
local FISHINGTEXTURE = "Interface\\Icons\\Trade_Fishing"

local AddingLure = false

local ButtonMap = {};
ButtonMap["right"] = "RightButtonUp";
ButtonMap["button4"] = "Button4Up";
ButtonMap["button5"] = "Button5Up";

function FAOptions(uiType, uiName)
	local options = {
		type = 'group',
		icon = FISHINGTEXTURE,
		name = L["Fishing Ace!"],
		get = function(key) return db[key.arg] end,
		set = function(key, val) db[key.arg] = val end,
		args = {
			loot = {
				type = 'toggle',
				name = L["Auto Loot"],
				desc = L["AutoLootMsg"],
				arg = "loot",
				order = 1,
			},
			lure = {
				type = 'toggle',
				name = L["Auto Lures"],
				desc = L["AutoLureMsg"],
				arg = "lure",
				order = 2,
			},
			sound = {
				type = 'toggle',
				name = L["Enhance Sounds"],
				desc = L["EnhanceSoundsMsg"],
				arg = "sound",
				order = 3,
			},
			partial = {
				type = 'toggle',
				name = L["Partial Gear"],
				desc = L["PartialGearMsg"],
				arg = "partial",
				order = 4,
			},
			action = {
				type = 'toggle',
				name = L["Use Action"],
				desc = L["UseActionMsg"],
				arg = "action",
				order = 5,
			},
			bobber = {
				type = 'toggle',
				name = L["Watch Bobber"],
				desc = L["WatchBobberMsg"],
				arg = "bobber",
				order = 6,
			},
			volume = {
				type = 'range',
				name = L["Volume"],
				desc = L["VolumeMsg"],
				arg = "volume",
				min = 0,
				max = 100,
				order = 7,
			},
			castingkey = {
				type = "select",
				desc = L["CastingKeyMsg"],
				name = L["Casting Key"],
				style = "dropdown",
				arg = "castingkey",
				values = {
					none = NONE,
					control = CTRL_KEY_TEXT,
					shift = SHIFT_KEY_TEXT,
				},
				order = 8,
			},
			button = {
				type = "select",
				desc = L["MouseButtonMsg"],
				name = L["Mouse Button"],
				style = "dropdown",
				arg = "button",
				values = {
					right = KEY_BUTTON2,
					button4 = KEY_BUTTON4,
					button5 = KEY_BUTTON5,
				},
				set = function(info, val)
					FL:SetSAMouseEvent(ButtonMap[val])
					db[info[#info]] = val
				end,
				order = 9,
			},
		}
	}
	if (uiType == "dialog") then
		options.args["desc"] = {
			type = "description",
			order = 0,
			name = L["Description"],
		}
	else
		local desc;
		for arg, info in pairs(options.args) do
			if (options.args[arg].type == 'toggle') then
				local onoff = db[info.arg] and "FF00FF00" .. L["on"] or "FFFF0000" .. L["off"];
				desc = " [|c" .. onoff .. "|r]";
			elseif (db[info.arg]) then
				desc = " [" .. db[info.arg] .. "]";
			else
				desc = "";
			end
			options.args[arg].desc = options.args[arg].desc .. desc;
		end
	end

	-- Debugging
	-- options.db = db

	return options
end

FishingAce = LibStub("AceAddon-3.0"):NewAddon("FishingAce", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0",
	"AceHook-3.0")

local LastLure
local casting_timer = nil
function FishingAce:PostCastUpdate(self)
	local stop = true
	if (not InCombatLockdown()) then
		if (AddingLure) then
			--local sp, sub, txt, tex, st, et, trade, int = UnitChannelInfo("player");
			local name, _, _, _, _, _, _, _, _, _ = UnitChannelInfo("player");
			local _, lure = FL:GetPoleBonus();
			if (not name or (lure and lure == LastLure.b)) then
				AddingLure = false;
				FL:UpdateLureInventory();
			else
				stop = false;
			end
		end
		if (stop and casting_timer) then
			FishingAce:CancelTimer(casting_timer)
			casting_timer = nil
		end
	end
end

local function HideAwayAll(self, button, down)
	if (not casting_timer) then
		casting_timer = FishingAce:ScheduleRepeatingTimer("PostCastUpdate", 1, self)
	end
end

AddonLoader = AddonLoader or {}
function FishingAce:OnInitialize()
	local defaults = {
		profile = {
			loot = true,
			lure = false,
			sound = true,
			partial = false,
			volume = 100,
			action = false,
			bobber = false,
			castingkey = "none",
			button = "right",
		},
	}
	self.db = LibStub("AceDB-3.0"):New("FishingAceDB", defaults, "Default")
	db = self.db.profile

	if AddonLoader and AddonLoader.RemoveInterfaceOptions then
		AddonLoader:RemoveInterfaceOptions(ADDONNAME)
	end

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(ADDONNAME, FAOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDONNAME, L["Fishing Ace!"])

	-- 	L["Slash-Commands"] = { "/fishingace", "/fa" }
	local config = LibStub("AceConfigCmd-3.0")
	config:CreateChatCommand("fishingace", ADDONNAME)
	config:CreateChatCommand("fa", ADDONNAME)

	FL:CreateSAButton()
	FL:SetSAMouseEvent(ButtonMap[self.db.profile.button])
	FL:WatchBobber(false)
end

-- handle option keys for enabling casting
local key_actions = {
	["none"] = function(mouse) return mouse ~= "right"; end,
	["shift"] = function(mouse) return IsShiftKeyDown(); end,
	["control"] = function(mouse) return IsControlKeyDown(); end,
}
local function CastingKeys()
	local setting = db.castingkey;
	local mouse = db.button;
	if (setting and key_actions[setting]) then
		return key_actions[setting](mouse);
	else
		return false;
	end
end

local function HijackCheck()
	local self = FishingAce;
	if (not InCombatLockdown() and
			(CastingKeys() or
				FL:IsFishingReady(self.db.profile.partial))) then
		return true
	end
end

-- do everything we think is necessary when we start fishing
-- even if we didn't do the switch to a fishing pole
local efsv = nil
local function EnhanceFishingSounds(self, enhance)
	if (self.db.profile.sound) then
		if (enhance) then
			local mv = tonumber(GetCVar("Sound_MasterVolume"))
			local mu = tonumber(GetCVar("Sound_MusicVolume"))
			local av = tonumber(GetCVar("Sound_AmbienceVolume"))
			local sv = tonumber(GetCVar("Sound_SFXVolume"))
			local pd = tonumber(GetCVar("particleDensity"))
			if (not efsv) then
				-- collect the current value
				efsv = {}
				efsv["Sound_MasterVolume"] = mv
				efsv["Sound_MusicVolume"] = mu
				efsv["Sound_AmbienceVolume"] = av
				efsv["Sound_SFXVolume"] = sv
				efsv["particleDensity"] = pd;
				-- turn 'em off!
				SetCVar("Sound_MasterVolume", FishingAce.db.profile.volume / 100.0)
				SetCVar("Sound_SFXVolume", 1.0)
				SetCVar("Sound_MusicVolume", 0.0)
				SetCVar("Sound_AmbienceVolume", 0.0)
				SetCVar("particleDensity", 1.0)
			end
		else
			if (efsv) then
				for setting, value in pairs(efsv) do
					SetCVar(setting, value)
				end
				efsv = nil
			end
		end
	end
	FL:WatchBobber(self.db.profile.bobber)
end

local function StartFishingMode(self)
	if (not self.startedFishing) then
		-- Disable Click-to-Move if we're fishing
		if (GetCVarBool("autoInteract")) then
			self.resetClickToMove = true
			SetCVar("autoInteract", "0")
		end
		self.startedFishing = GetTime()
		EnhanceFishingSounds(self, true)
	end
	FL:WatchBobber(false)
end

local function StopFishingMode(self)
	if (self.startedFishing) then
		EnhanceFishingSounds(self, false)
		self.startedFishing = nil
	end
	if (self.resetClickToMove) then
		-- Re-enable Click-to-Move if we changed it
		SetCVar("autoInteract", "1")
		self.resetClickToMove = nil
	end
end

local function FishingMode(self)
	if (FL:IsFishingReady(self.db.profile.partial)) then
		StartFishingMode(self)
	else
		StopFishingMode(self)
	end
end

local function SetupLure()
	if (not AddingLure and FL:IsFishingPole()) then
		if (FishingAce.db.profile.lure) then
			local pole, tempenchant = FL:GetPoleBonus()
			local state, bestlure = FL:FindBestLure(tempenchant, 0, true)
			if (state and bestlure) then
				FL:InvokeLuring(bestlure.id)
				AddingLure = true
				LastLure = bestlure
				return true
			end
		end
	end
	return false
end

FishingBuddy = FishingBuddy or {}
function FishingAce:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("GLOBAL_MOUSE_DOWN")

	if (FishingBuddy and FishingBuddy.Message) then
		FishingBuddy.Message(L["Active"]);
	end
end

function FishingAce:OnDisable()
	self:UnregisterAllEvents()
	if (FishingBuddy and FishingBuddy.Message) then
		FishingBuddy.Message(L["Standby"])
	end
end

function FishingAce:GLOBAL_MOUSE_DOWN(...)
	local button = select(2, ...)
	if (FL:CheckForDoubleClick(button) and HijackCheck()) then
		-- We're stealing the mouse-up event, make sure we exit MouseLook
		if (IsMouselooking()) then
			MouselookStop()
		end
		if (not SetupLure()) then
			FL:InvokeFishing(FishingAce.db.profile.action)
		end
		FL:OverrideClick(HideAwayAll)
	end
end

function FishingAce:ITEM_LOCK_CHANGED()
	FishingMode(self)
end

function FishingAce:PLAYER_EQUIPMENT_CHANGED()
	FishingMode(self)
end

function FishingAce:LOOT_OPENED()
	if (IsFishingLoot()) then
		-- if we want to autoloot, and Blizz isn't, let's grab stuff
		if (FishingAce.db.profile.loot and (GetCVar("autoLootDefault") ~= "1")) then
			for index = 1, GetNumLootItems(), 1 do
				LootSlot(index);
			end
		end
		FL:ExtendDoubleClick();
		LureState = 0;
	end
end

function FishingAce:PLAYER_ENTERING_WORLD()
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

function FishingAce:PLAYER_LEAVING_WORLD()
	self:UnregisterEvent("ITEM_LOCK_CHANGED")
	self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
end
