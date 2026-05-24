--!strict

local ServerStorage = game:GetService("ServerStorage")

local src = script.Parent.Parent

local Trove = require(src.Utility.Trove)

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

--[[
	Starts searching for the SOUNDS folder location.
]]
function AutoSearchLocation.Start(pluginCleaner: Trove.Trove)
	AutoSearchLocation.SetFolder(nil)

	pluginCleaner:Connect(ServerStorage.DescendantAdded, function(descendant: Instance)
		if not descendant:IsA("Configuration") or descendant.Name ~= "SOUNDS" then
			return
		end

		AutoSearchLocation.SetFolder(descendant)
	end)

	pluginCleaner:Connect(ServerStorage.DescendantRemoving, function(descendant: Instance)
		if not descendant:IsA("Configuration") or descendant.Name ~= "SOUNDS" then
			return
		end

		AutoSearchLocation.SetFolder(nil)
	end)
end

return AutoSearchLocation
