--!strict
--!optimize 2

local src = script.Parent.Parent

local FormatMessage = require(src.Utility.FormatMessage)
local Profiler = require(src.Utility.Profiler)

local Settings = require(src.Tools.Settings)
local SoundsLocation = require(src.Tools.SoundsLocation)

--[[
    This module performs a full bake of the sounds folder, returning an array of all the sound names in the folder.

	This has been optimized as much as possible as this is the most important function for the plugin.
]]
local FullBake = {}

--[[
    @param folder: Configuration? -- Providing the folder is faster but not required.

    @return { string } -- an array of all the sound names in the folder.

	This function performs a full bake of the sounds folder, returning an array of all the sound names in the folder.
]]
function FullBake.Now(folder: Configuration?): { string }
	local bakingDiagnostics = Profiler.NewDiagnostic(Settings.GetDiagnosticsEnabled, "FullBake")
	local bakingDebugProfile = Profiler.NewDebugProfile("FullBake")

	local function endProfile()
		bakingDiagnostics(nil, script, 28)
		bakingDebugProfile()
	end

	--

	local contents: { Name: string, SoundNames: { string } } = { Name = "FullBakeResult", SoundNames = {} }
	local soundNamesHash: { [string]: boolean } = {}

	local soundsFolder: Configuration? = folder

	if not folder then
		local formatedLocation: string? = Settings.GetSoundsLocation()

		if not formatedLocation then
			FormatMessage.Error("Could not fetch sounds folder location for full bake!")

			endProfile()

			return contents
		end

		soundsFolder = SoundsLocation.GetSoundsFolderFromLocation(formatedLocation :: string)
	end

	if not soundsFolder then
		FormatMessage.Error("Could not find sounds folder at the provided location for full bake!")

		endProfile()

		return contents
	end

	--if folder is provided it starts to do heavy stuff here
	local sounds: { Sound } = soundsFolder:QueryDescendants("Sound")
	local soundCount: number = #sounds

	if soundCount == 0 then
		FormatMessage.Warn("No sounds found in the specified sounds folder for full bake!")

		endProfile()

		return contents
	end

	local soundNamesIndex: number = 0
	local soundNames = contents.SoundNames

	for _, sound in ipairs(sounds) do
		local name: string = sound.Name

		if not soundNamesHash[name] then
			soundNamesHash[name] = true
			soundNamesIndex += 1

			soundNames[soundNamesIndex] = name
		end
	end

	endProfile()

	return contents
end

return FullBake
