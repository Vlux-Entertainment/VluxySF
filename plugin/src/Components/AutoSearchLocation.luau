--!strict

local src = script.Parent.Parent

local Settings = require(src.Tools.Settings)
local SoundsLocation = require(src.Tools.SoundsLocation)

--[[
	This module automatically searches for the sounds folder in ServerStorage and updates the settings with the location of the sounds folder.
]]
local AutoSearchLocation = {}

--[[
	@param location: Configuration? -- the new location of the sounds folder, or nil to search for the sounds folder automatically.

	This function updates the settings with the location of the sounds folder. If a location is provided, it will use that location.
]]
function AutoSearchLocation.SetFolder(location: Configuration?)
	local formatLocation = nil
	if location then
		formatLocation = SoundsLocation.GetLocationFromSoundsFolder(location)
	else
		local _, fLocation = SoundsLocation.AutoFindFormatLocation()
		formatLocation = fLocation
	end

	Settings.SetSoundsLocation(formatLocation)
end

return AutoSearchLocation
