--!strict

local ServerStorage = game:GetService("ServerStorage")

--for now this works but an event version would be better in the future prob.

local Settings = require(script.Parent.Tools.Settings)
local SoundsLocation = require(script.Parent.Tools.SoundsLocation)

-- This module handles the auto searching for the sounds folder location and updating it in the plugin's settings.
local AutoSearchLocation = {}

--
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

--
function AutoSearchLocation.Start()
	AutoSearchLocation.SetFolder(nil)

	ServerStorage.DescendantAdded:Connect(function(descendant: Instance)
		if not descendant:IsA("Configuration") or descendant.Name ~= "SOUNDS" then
			return
		end

		AutoSearchLocation.SetFolder(descendant)
	end)

	ServerStorage.DescendantRemoving:Connect(function(descendant: Instance)
		if not descendant:IsA("Configuration") or descendant.Name ~= "SOUNDS" then
			return
		end

		AutoSearchLocation.SetFolder(nil)
	end)
end

return AutoSearchLocation
