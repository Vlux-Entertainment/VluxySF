--!strict

local src = script.Parent.Parent

local FormatMessage = require(src.Utility.FormatMessage)

local Settings = require(src.Tools.Settings)
local SoundsLocation = require(src.Tools.SoundsLocation)

--[[
    This module performs a full bake of the sounds folder, returning an array of all the sound names in the folder.
]]
local FullBake = {}

--[[
    @param folder: Configuration? -- Providing the folder is faster but not required.

    @return { string } -- an array of all the sound names in the folder.

	This function performs a full bake of the sounds folder, returning an array of all the sound names in the folder.
]]
function FullBake.Now(folder: Configuration?): { string }
	local soundNames = {}

	local soundsFolder: Configuration? = folder

	if not folder then
		local formatedLocation = Settings.GetSoundsLocation()
		if not formatedLocation then
			FormatMessage.Error("Could not fetch sounds folder location for full bake!")
			return {}
		end

		soundsFolder = SoundsLocation.GetSoundsFolderFromLocation(formatedLocation :: string)
	end

	if not soundsFolder then
		FormatMessage.Error("Could not find sounds folder at the provided location for full bake!")
		return {}
	end

	--if folder is provided it starts to do stuff here
	local sounds = soundsFolder:QueryDescendants("Sound")
	if #sounds == 0 then
		FormatMessage.Warn("No sounds found in the specified sounds folder for full bake!")
		return {}
	end

	for _, sound in sounds do
		if table.find(soundNames, sound.Name) then
			continue
		end

		table.insert(soundNames, sound.Name)
	end

	return { Name = "FullBakeResult", SoundNames = soundNames }
end

return FullBake
