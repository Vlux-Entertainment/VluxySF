--!strict

local library = script.Parent.Parent

local Jitter = require(library.Sections.Jitter)

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class SoundPresets
	
	A collection of preset functions for applying common sound effects, such as jitter, to Sound instances. These presets can be easily applied to sounds to achieve dynamic and natural variations in sound playback.
]=]
local SoundPresets = {}

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within SoundPresets

	@param ... (Sound) -> () -- A variable number of preset functions to combine.

	@return (Sound) -> () -- A new preset function that applies all the provided presets in sequence.

	Combines multiple sound presets into a single preset function, allowing for modular and reusable sound configurations.
]=]
function SoundPresets.Combine(...: (Sound) -> ()): (Sound) -> ()
	local presets: { (Sound) -> () } = { ... }
	local presetCount: number = #presets

	return function(sound: Sound)
		for i = 1, presetCount do
			presets[i](sound)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within SoundPresets

	@param parent Instance -- The parent instance to which the sound will be attached.

	@return (Sound) -> () -- A preset function that sets the parent of a sound to the specified instance.

	A simple preset that assigns a parent to a sound, useful for organizing sounds within the game hierarchy.
]=]
function SoundPresets.Parent(parent: Instance): (Sound) -> ()
	return function(sound: Sound)
		sound.Parent = parent
	end
end

--[=[
	@within SoundPresets

	@param volume number -- The volume level to set for the sound (0 to 10).

	@return (Sound) -> () -- A preset function that sets the volume of a sound to the specified level.

	A preset for setting a specific volume level on a sound.
]=]
function SoundPresets.Volume(volume: number): (Sound) -> ()
	return function(sound: Sound)
		sound.Volume = volume
	end
end

--[=[
	@within SoundPresets

	@param speed number -- The playback speed to set for the sound (0.5 to 2, where 1 is normal speed).

	@return (Sound) -> () -- A preset function that sets the playback speed of a sound to the specified value.

	A preset for setting a specific playback speed on a sound.
]=]
function SoundPresets.PlaybackSpeed(speed: number): (Sound) -> ()
	return function(sound: Sound)
		sound.PlaybackSpeed = speed
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within SoundPresets

	@param center number? -- The central volume level around which the jitter will occur (default: 0.5).
	@param spread number? -- The maximum deviation from the center volume level (default: 0.1).

	@return (Sound) -> () -- A preset function that applies random jitter to a sound's volume, creating more dynamic and less repetitive audio effects.

	A preset that applies random jitter to a sound's volume, creating more dynamic and less repetitive audio effects.
]=]
function SoundPresets.NaturalVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.UnitLog(center or 0.5, spread or 0.1)

	return function(sound: Sound)
		sound.Volume = jitter()
	end
end

--[=[
	@within SoundPresets

	@param center number? -- The central playback speed around which the jitter will occur (default: 1).
	@param spread number? -- The maximum deviation from the center playback speed (default: 0.1).

	@return (Sound) -> () -- A preset function that applies random jitter to a sound's playback speed, creating more dynamic and less repetitive audio effects.

	A preset that applies random jitter to a sound's playback speed, creating more dynamic and less repetitive audio effects.
]=]
function SoundPresets.NaturalPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.UnitLog(center or 1, spread or 0.1)

	return function(sound: Sound)
		sound.PlaybackSpeed = jitter()
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within SoundPresets

	@param center number? -- The central volume level around which the jitter will occur (default: 0.5).
	@param spread number? -- The maximum deviation from the center volume level (default: 0.1).

	@return (Sound) -> () -- A preset function that applies random jitter to a sound's volume, creating more dynamic and less repetitive audio effects.

	A preset that applies random jitter to a sound's volume, creating more dynamic and less repetitive audio effects.
]=]
function SoundPresets.RandomVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Default(center or 0.5, spread or 0.1)

	return function(sound: Sound)
		sound.Volume = jitter()
	end
end

--[=[
	@within SoundPresets

	@param center number? -- The central playback speed around which the jitter will occur (default: 1).
	@param spread number? -- The maximum deviation from the center playback speed (default: 0.1).

	@return (Sound) -> () -- A preset function that applies random jitter to a sound's playback speed, creating more dynamic and less repetitive audio effects.

	A preset that applies random jitter to a sound's playback speed, creating more dynamic and less repetitive audio effects.
]=]
function SoundPresets.RandomPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Default(center or 1, spread or 0.1)

	return function(sound: Sound)
		sound.PlaybackSpeed = jitter()
	end
end

------------------------------------------------------------------------------------------------------------------------

return SoundPresets
