--!strict

local ServerStorage = game:GetService("ServerStorage")

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

local SoundsLocation = {}

-- This module handles the location of the sounds folder within ServerStorage. It provides functions to get the location of the sounds folder, retrieve the sounds folder instance from a given location, and automatically find the sounds folder if it exists.
function SoundsLocation.GetLocationFromSoundsFolder(location: Configuration): string
	local fullLocations = {}

	local currentInstance: Instance = location
	local function recurseLocation()
		table.insert(fullLocations, currentInstance.Name)

		if currentInstance.Parent == ServerStorage then
			return
		end

		currentInstance = currentInstance.Parent :: Instance

		recurseLocation()
	end
	recurseLocation()

	table.sort(fullLocations, function(a0, a1): boolean
		return a0 < a1
	end)

	local formatedLocation = "ServerStorage." .. table.concat(fullLocations, ".")

	--print(formatedLocation) --test

	return formatedLocation
end

-- Retrieves the sounds folder instance from a given formatted location string. The function checks if a Configuration exists at the specified location within ServerStorage and returns it. If the Configuration cannot be found, it throws an error with a formatted message indicating the issue.
function SoundsLocation.GetSoundsFolderFromLocation(formatedLocation: string): Configuration?
	local current: any = game

	for _, instanceName in pairs(formatedLocation:split(".")) do
		local nextChild = current:FindFirstChild(instanceName)
		if not nextChild then
			FormatMessage.Error("The formated location was impartial!")
			return nil
		end

		current = nextChild
	end

	return current
end

-- Auto finds were the sounds folder should be location and returns a formatted location.
function SoundsLocation.AutoFindFormatLocation(): (Configuration?, string)
	local soundsFolders = ServerStorage:QueryDescendants("Configuration #SOUNDS")
	local soundsFolder = soundsFolders[1]

	if not soundsFolder then
		FormatMessage.Error(
			"Could not locate a Configuration named SOUNDS to bake! Please create a Configuration named SOUNDS in ServerStorage to use the plugin."
		)
		return nil, "error"
	end

	if #soundsFolders > 1 then
		FormatMessage.Warn("Multiple Configurations named SOUNDS found within ServerStorage!")
	end

	return soundsFolder, SoundsLocation.GetLocationFromSoundsFolder(soundsFolder)
end

return SoundsLocation
