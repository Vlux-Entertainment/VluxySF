--!strict

local ServerStorage = game:GetService("ServerStorage")

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)

--[[
	This module handles the location of the sounds folder within ServerStorage.
]]
local SoundsLocation = {}

--[[
	@param location Configuration -- The Configuration instance representing the sounds folder.

	@return string -- The formatted location of the sounds folder.

	Returns a formatted string representing the location of the sounds folder within ServerStorage, based on the hierarchy of instances leading to it.
]]
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

--[[
	@param formatedLocation string -- The formatted location of the sounds folder.

	@return Configuration? -- The Configuration instance representing the sounds folder, or nil if it cannot be found.

	Returns the Configuration instance representing the sounds folder based on the provided formatted location string. The formatted location should be in the format "ServerStorage.Folder1.Folder2.SOUNDS".
]]
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

------------------------------------------------------------------------------------------------------------------------

--[[
	@return Configuration? -- The Configuration instance representing the sounds folder, or nil if it cannot be found.
	@return string -- The formatted location of the sounds folder, or "error" if the sounds folder cannot be found.

	Automatically finds the sounds folder within ServerStorage by searching for a Configuration named "SOUNDS".
]]
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
