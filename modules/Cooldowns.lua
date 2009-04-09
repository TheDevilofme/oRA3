local oRA = LibStub("AceAddon-3.0"):GetAddon("oRA3")
local util = oRA.util
local module = oRA:NewModule("Cooldowns", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("oRA3")
local AceGUI = LibStub("AceGUI-3.0")

local _, playerClass = UnitClass("player")

local bloodlustId = UnitFactionGroup("player") == "Alliance" and 32182 or 2825

local spells = {
	DRUID = {
		[26994] = 1200, -- Rebirth
		[29166] = 360, -- Innervate
		[17116] = 180, -- Nature's Swiftness
		[5209] = 180, -- Challenging Roar
	},
	HUNTER = {
		[34477] = 30, -- Misdirect
		[5384] = 30, -- Feign Death
	},
	MAGE = {
		[45438] = 300, -- Iceblock
		[2139] = 24, -- Counterspell
	},
	PALADIN = {
		[19752] = 1200, -- Divine Intervention
		[642] = 300, -- Divine Shield
		[10278] = 300, -- Hand of Protection
		[6940] = 120, -- Hand of Sacrifice
		[498] = 300, -- Divine Protection
		[633] = 1200, -- Lay on Hands
	},
	PRIEST = {
		[33206] = 180, -- Pain Suppression
		[47788] = 180, -- Guardian Spirit
		[6346] = 180, -- Fear Ward
	},
	ROGUE = {
		[31224] = 90, -- Cloak of Shadows
		[38768] = 10, -- Kick
		[1725] = 30, -- Distract
	},
	SHAMAN = {
		[bloodlustId] = 600, -- Bloodlust/Heroism
		[20608] = 3600, -- Reincarnation
		[16190] = 300, -- Mana Tide Totem
		[2894] = 1200, -- Fire Elemental Totem
		[2062] = 1200, -- Earth Elemental Totem
		[16188] = 180, -- Nature's Swiftness
	},
	WARLOCK = {
		[27239] = 1800, -- Soulstone Resurrection
		[29858] = 300, -- Soulshatter
	},
	WARRIOR = {
		[871] = 300, -- Shield Wall
		[12975] = 300, -- Last Stand
		[6554] = 10, -- Pummel
		[1161] = 180, -- Challenging Shout
	},
	DEATHKNIGHT = {
		[42650] = 1200, -- Army of the Dead
		[61999] = 300, -- Raise Ally
		[49028] = 180, -- Dancing Rune Weapon
		[49206] = 180, -- Summon Gargoyle
		[49916] = 120, -- Strangulate
		[49576] = 35, -- Death Grip
		[51271] = 60, -- Unbreakable Armor
	},
}

local classes = {}
for k in pairs(spells) do
	classes[k] = L[k]
end

local frame = nil
local db = nil

local bopModifier = 0
local reincModifier = 0

local trackedSpells = {}
local broadcastSpells = {}

local function updateSpells()
	wipe(broadcastSpells)
	wipe(trackedSpells)
	-- These are the spells we broadcast to the raid
	for spell, cd in pairs(spells[playerClass]) do
		if spell == 10278 then
			cd = cd - bopModifier
		elseif spell == 20608 then
			cd = cd - reincModifier
		end
		broadcastSpells[GetSpellInfo(spell)] = cd
	end
	for spell in pairs(db.spells) do
		trackedSpells[GetSpellInfo(spell)] = true
	end
	--AceLibrary("AceConsole-2.0"):PrintLiteral(trackedSpells)
end

local function showConfig()
	frame.frame:SetParent(_G["oRA3FrameSub"])
	frame.frame:SetPoint("TOPLEFT", _G["oRA3FrameSub"], "TOPLEFT", 0, -60)
	frame.frame:SetPoint("BOTTOMRIGHT", _G["oRA3FrameSub"], "BOTTOMRIGHT", -4, 4)
	frame.frame:Show()
end

local function hideConfig()
	frame.frame:Hide()
end

function module:OnRegister()
	local database = oRA.db:RegisterNamespace("Cooldowns", {
		profile = {
			spells = {
				[26994] = true,
				[19752] = true,
				[20608] = true,
				[27239] = true,
			},
		},
	})
	db = database.profile
	
	self:CreateFrame()

	oRA:RegisterPanel(
		L["Cooldowns"],
		showConfig,
		hideConfig
	)
end

function module:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("CHARACTER_POINTS_CHANGED")
	if playerClass == "SHAMAN" then
		local resTime = GetTime()
		local ankhs = GetItemCount(17030)
		self:RegisterEvent("PLAYER_ALIVE", function()
			resTime = GetTime()
		end)
		self:RegisterEvent("BAG_UPDATE", function()
			if (GetTime() - (resTime or 0)) > 1 then return end
			local newankhs = GetItemCount(17030)
			if newankhs == (ankhs - 1) then
				local name = GetSpellInfo(20608)
				oRA:SendComm("Cooldown", name, broadcastSpells[name]) -- Spell name + CD in seconds
			end
			ankhs = newankhs
		end)
	end
	
	oRA.RegisterCallback(self, "OnCommCooldown")
	
	updateSpells()
end

function module:OnCommCooldown(commType, sender, spell, cd)
	if not trackedSpells[spell] then return end
	print("We should show a cooldown for " .. spell .. " (" .. tostring(cd) .. ")")
end

function module:CHARACTER_POINTS_CHANGED()
	if playerClass == "PALADIN" then
		local _, _, _, _, rank = GetTalentInfo(2, 5)
		bopModifier = rank * 60
		updateSpells()
	elseif playerClass == "SHAMAN" then
		local _, _, _, _, rank = GetTalentInfo(3, 3)
		reincModifier = rank * 600
		updateSpells()
	end
end

function module:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
	if unit ~= "player" then return end
	if broadcastSpells[spell] then
		oRA:SendComm("Cooldown", spell, broadcastSpells[spell]) -- Spell name + CD in seconds
	end
end

local tmp = {}
function module:CreateFrame()
	if frame then return end
	frame = AceGUI:Create("ScrollFrame")

	local moduleDescription = AceGUI:Create("Label")
	moduleDescription:SetText(L["Select which cooldowns to display using the dropdown and checkboxes below. Each class has a small set of spells available that you can view using the bar display. Select a class from the dropdown and then configure the spells for that class according to your own needs."])
	moduleDescription:SetFullWidth(true)
	moduleDescription:SetFontObject(GameFontHighlight)

	local function spellCheckboxCallback(widget, event, value)
		if not widget.oRACooldownID then return end
		db.spells[widget.oRACooldownID] = value and true or nil
		widget:SetValue(value)
		updateSpells()
	end

	local group = AceGUI:Create("DropdownGroup")
	group:SetTitle(L["Select class"])
	group:SetGroupList(classes)
	group:SetCallback("OnGroupSelected", function(widget, event, class)
		widget:ReleaseChildren()
		wipe(tmp)
		for id in pairs(spells[class]) do
			table.insert(tmp, id)
		end
		table.sort(tmp)
		for i, v in ipairs(tmp) do
			local name = GetSpellInfo(v)
			local checkbox = AceGUI:Create("CheckBox")
			checkbox:SetLabel(name)
			checkbox:SetValue(db.spells[v] and true or false)
			checkbox.oRACooldownID = v
			checkbox:SetCallback("OnValueChanged", spellCheckboxCallback)
			checkbox:SetFullWidth(true)
			widget:AddChild(checkbox)
		end
	end)
	group.dropdown:SetWidth(120)
	group:SetGroup(playerClass)
	group:SetFullWidth(true)

	frame:AddChild(moduleDescription)
	frame:AddChild(group)
end
