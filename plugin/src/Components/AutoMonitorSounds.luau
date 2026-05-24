--!strict

local src = script.Parent.Parent

local Trove = require(src.Utility.Trove)

local Settings = require(src.Tools.Settings)
local SoundsLocation = require(src.Tools.SoundsLocation)

local autoMonitorCleaner: Trove.Trove

--[[
    This module monitors the sounds folder for changes and sends updates to the client when changes are made if auto bake is enabled.
]]
local AutoMonitorSounds = {}

--[[
    Clears the auto monitor for sounds, disconnecting all events and connections.
]]
function AutoMonitorSounds.Clear()
	if autoMonitorCleaner then
		autoMonitorCleaner:Clean()
	end
end

--[[
	@param onChange: (Configuration) -> () -- The function to call when a change is detected in the sounds folder.

    Creates a new monitor for the sounds folder, which will automatically send updates to the client when changes are made to the sounds folder if auto bake is enabled.
]]
function AutoMonitorSounds.NewMonitor(onChange: (Configuration) -> ())
	AutoMonitorSounds.Clear()
	autoMonitorCleaner = Trove.new()

	local formatedLocation = Settings.GetSoundsLocation()
	if not formatedLocation then
		return
	end

	local folderInstance = SoundsLocation.GetSoundsFolderFromLocation(formatedLocation)
	if not folderInstance then
		return
	end

	local function bakeAndSend()
		if not Settings.GetAutoBakeEnabled() then
			return
		end

		onChange(folderInstance)
	end

	local currentSounds = {}
	local function monitorForNameChange(sound: Sound)
		if currentSounds[sound] then
			return
		end

		currentSounds[sound] = true

		autoMonitorCleaner:Connect(sound.Changed, function(property)
			if property ~= "Name" then
				return
			end

			bakeAndSend()
		end)
	end

	for _, descendant in folderInstance:QueryDescendants("Sound") do
		monitorForNameChange(descendant)
	end

	bakeAndSend()
	autoMonitorCleaner:Connect(folderInstance.DescendantAdded, function(descendant: Instance)
		if not descendant:IsA("Sound") then
			return
		end

		monitorForNameChange(descendant)

		bakeAndSend()
	end)

	autoMonitorCleaner:Connect(folderInstance.DescendantRemoving, function(descendant: Instance)
		if descendant:IsA("Sound") and currentSounds[descendant] then
			currentSounds[descendant] = nil
		end

		bakeAndSend()
	end)
end

--[[
	@param onChange: (Configuration) -> () -- The function to call when a change is detected in the sounds folder.

    Initializes the auto monitor for sounds.
]]
function AutoMonitorSounds.Init(onChange: (Configuration) -> ())
	AutoMonitorSounds.NewMonitor(onChange)

	Settings.ListenSoundsLocationChanged():Connect(function(_location: string)
		AutoMonitorSounds.NewMonitor(onChange)
	end)
end

return AutoMonitorSounds
