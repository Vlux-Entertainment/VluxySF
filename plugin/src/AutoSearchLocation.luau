--!strict

--for now this works but an event version would be better in the future prob.

local Settings = require(script.Parent.Tools.Settings)
local SoundsLocation = require(script.Parent.Tools.SoundsLocation)

-- This module handles the auto searching for the sounds folder location and updating it in the plugin's settings.
local AutoSearchLocation = {}

-- Returns whether the auto search was successful and an error message if it was not.
function AutoSearchLocation.Start(): (boolean, string?)
	local function setSoundsLocation()
		local _, formatLocation = SoundsLocation.AutoFindFormatLocation()
		Settings.SetSoundsLocation(formatLocation)
	end

	task.spawn(function()
		setSoundsLocation()

		while true do
			task.wait(3)

			if not Settings.GetPluginEnabled() then
				continue
			end

			setSoundsLocation()
		end
	end)

	return false, nil
end

return AutoSearchLocation
