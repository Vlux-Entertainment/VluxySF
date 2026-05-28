--!strict

local library = script.Parent.Parent

local Preload = require(library.Tools.Preload)
local SoundMisc = require(library.Tools.SoundMisc)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Misc
	
	A collection of functions to generate random jitter values for sound properties, allowing for dynamic and natural variations in sound playback.
]=]
local Misc = {}

--[=[
	@within Misc

	@param ... number | string | Sound | SoundDefinition -- A variable number of sound identifiers, which can be sound locations, Sound instances, or SoundDefinitions.

	Preloads through ContentProvider.
]=]
function Misc.PreloadSelected(...: number | string | Sound | Types.SoundDefinition)
	return Preload.Selected(...)
end

--[=[
	@within Misc

	@param sound Sound -- The sound instance to analyze.

	@return number -- The estimated play length of the sound, including any variations in playback speed.

	Calculates the estimated play length of a sound instance by considering its SoundId and any attached sound effects that may influence its duration.
]=]
function Misc.GetPlayLength(sound: Sound): number
	return SoundMisc.GetEstimatedPlayLength(sound)
end

return Misc
