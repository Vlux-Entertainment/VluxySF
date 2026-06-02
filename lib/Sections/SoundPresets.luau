--!strict

local library = script.Parent.Parent

local Jitter = require(library.Sections.Jitter)

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class SoundPresets
	
	Presets are functions that you can apply to your sounds to quickly change reoccuring property values.

	:::info
	- Presets are closures that get passed to your fetching functions.
	- You can create your own presets and combine them with the built in ones.
	- When a preset runs everything should be cleaned up before exiting the function block.
	:::

	:::tip
	You can also make your own presets and store them in a module for easy access.
	```lua
		local CustomPresets = {}

		function CustomPrests.DoSomthing(doTheThing: boolean): (Sound) -> ()
			return function(sound: Sound)
				if doTheThing then
					sound.Volume = 0.5
				else
					sound.Volume = 1
				end
			end
		end

		return CustomPresets
	```
	:::
]=]
local SoundPresets = {}

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within SoundPresets

	@param ... (Sound) -> () -- Your Preset Closures to combine.

	@return (Sound) -> () -- Closure of the combined presets.

	Combines presets together into 1 reusable preset.

	:::info
	Presets are applied in sequence from first to last.
	:::

	```lua
	local myCombinedPreset = SoundPresets.Combine(
		SoundPresets.NaturalPlaybackJitter(0.8, 0.1),
		SoundPresets.NaturalVolumeJitter(0.7, 0.15)
	)

	local myCombinedPreset2 = SoundPresets.Combine(
		myCombinedPreset,
		SoundPresets.Parent(workspace.Sounds)
	)

	local sound1 = VluxySF.Fetch("mySound1", nil, myCombinedPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myCombinedPreset)
	
	local sound3 = VluxySF.Fetch("mySound3", nil, myCombinedPreset2)
	local sound4 = VluxySF.Fetch("mySound4", nil, myCombinedPreset2)
	```
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

	@param parent Instance -- The parent to set the sound too.

	@return (Sound) -> () -- Closure of the preset.

	Sets the parent of a sound.

	```lua
	local myPreset = SoundPresets.Parent(workspace.Sounds)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
]=]
function SoundPresets.Parent(parent: Instance): (Sound) -> ()
	return function(sound: Sound)
		sound.Parent = parent
	end
end

--[=[
	@within SoundPresets

	@param volume number -- The volume to set the sound too.

	@return (Sound) -> () -- Closure of the preset.

	Sets the volume of a sound.

	```lua
	local myPreset = SoundPresets.Volume(0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
]=]
function SoundPresets.Volume(volume: number): (Sound) -> ()
	return function(sound: Sound)
		sound.Volume = volume
	end
end

--[=[
	@within SoundPresets

	@param speed number -- The playback speed to set for the sound too.

	@return (Sound) -> () -- Closure of the preset.

	Sets the playback speed of a sound.

	```lua
	local myPreset = SoundPresets.PlaybackSpeed(1.3)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
]=]
function SoundPresets.PlaybackSpeed(speed: number): (Sound) -> ()
	return function(sound: Sound)
		sound.PlaybackSpeed = speed
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within SoundPresets

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.

	Uses `Jitter.UnitLog` to apply a natural jitter to the volume of the sound.

	```lua
	local myPreset = SoundPresets.NaturalVolumeJitter(0.8, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
]=]
function SoundPresets.NaturalVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.UnitLog(center or 0.5, spread or 0.1)

	return function(sound: Sound)
		sound.Volume = jitter()
	end
end

--[=[
	@within SoundPresets

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.

	Uses `Jitter.UnitLog` to apply a natural jitter to the playback speed of the sound.

	```lua
	local myPreset = SoundPresets.NaturalPlaybackJitter(1, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
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

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.

	Uses `Jitter.Default` to apply a random jitter to the volume of the sound.

	```lua
	local myPreset = SoundPresets.RandomVolumeJitter(0.8, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
]=]
function SoundPresets.RandomVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Default(center or 0.5, spread or 0.1)

	return function(sound: Sound)
		sound.Volume = jitter()
	end
end

--[=[
	@within SoundPresets

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.

	Uses `Jitter.Default` to apply a random jitter to the playback speed of the sound.

	```lua
	local myPreset = SoundPresets.RandomPlaybackJitter(1, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```
]=]
function SoundPresets.RandomPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Default(center or 1, spread or 0.1)

	return function(sound: Sound)
		sound.PlaybackSpeed = jitter()
	end
end

------------------------------------------------------------------------------------------------------------------------

return SoundPresets
