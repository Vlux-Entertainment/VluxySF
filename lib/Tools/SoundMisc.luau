--!strict

local libarary = script.Parent.Parent

local Types = require(libarary.Types)

--[[
    Module responsible for miscellaneous sound-related utility functions that don't fit into other categories.
]]
local SoundMisc = {}

--[[
    @param sound Sound | SoundDefinition -- The Sound instance or SoundDefinition to estimate play length for.

    @return number -- The estimated remaining play length in seconds.

	Estimates the remaining play length of a sound, accounting for playback speed and current time position.
]]
function SoundMisc.GetEstimatedPlayLength(sound: Sound | Types.SoundDefinition): number
	local padding = 0.05

	--Sound and SoundDefinition should have the same properties.
	local realSoundInfo: any = sound
	if typeof(sound) == "table" then
		realSoundInfo = sound.Properties
	end

	if realSoundInfo.Looped then
		return math.huge
	end

	local playbackSpeed = realSoundInfo.PlaybackSpeed
	if playbackSpeed <= 0 or playbackSpeed ~= playbackSpeed then
		return padding
	end

	local timeLength = realSoundInfo.TimeLength
	if timeLength <= 0 or timeLength ~= timeLength then
		return padding
	end

	local timePosition = realSoundInfo.TimePosition
	if timePosition ~= timePosition then
		timePosition = 0
	end
	timePosition = math.clamp(timePosition, 0, timeLength)

	local remaining = (timeLength - timePosition) / playbackSpeed
	if remaining ~= remaining then
		return padding
	end

	return math.max(remaining + padding, padding)
end

return SoundMisc
