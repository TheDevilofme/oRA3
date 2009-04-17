local oRA = LibStub("AceAddon-3.0"):GetAddon("oRA3")
local util = oRA.util
local module = oRA:NewModule("Version")
local L = LibStub("AceLocale-3.0"):GetLocale("oRA3")

local versions = {} 
local f


function module:OnRegister()
	oRA:RegisterList(
		L["Version"],
		versions,
		L["Name"],
		L["Version"]
	)
	oRA.RegisterCallback(self, "OnStartup")
	oRA.RegisterCallback(self, "OnShutdown")
	oRA.RegisterCallback(self, "OnCommVersion")
	oRA.RegisterCallback(self, "OnGroupChanged")
end

function module:OnStartup()
	wipe(versions)
	-- no need to set onUpdate here, OnGroupChanged will fire as well.
end

function module:OnShutdown()
	f:SetScript("OnUpdate", nil)
end

do
	f = CreateFrame("Frame")
	local total = 0
	local function onUpdate(self, elapsed)
		total = total + elapsed
		if total > 10 then -- once every 10 seconds max.
			module:SendVersion()
			total = 0
			self:SetScript("OnUpdate", nil)
		end
	end

	function module:OnGroupChanged()
		if total > 0 then
			total = 0
		else
			f:SetScript("OnUpdate", onUpdate)
		end
	end
end

function module:SendVersion()
	oRA:SendComm("Version", oRA.VERSION)
end

function module:OnCommVersion(commType, sender, version)
	local k = util:inTable(versions, sender, 1)
	if not k then
		table.insert(versions, { sender } )
		k = util:inTable(versions, sender, 1)
	end
	versions[k][2] = version

	if version > oRA.VERSION then
		-- upgrade notice?
	end
	
	oRA:UpdateList(L["Version"])
end

