--!strict
--!optimize 2

local Jitter = require(script.Parent.Jitter)

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Presets
	
	Presets are functions that adjust a `Sound` as it is fetched, before it is parented, for property values you set
	over and over.

	:::info
	- Presets are closures that get passed to your fetching functions.
	- You can create your own presets and combine them with the built in ones.
	- When a preset runs everything should be cleaned up before exiting the function block.
	:::

	:::tip
	You can also make your own presets and store them in a module for easy access.
	```lua
	local CustomPresets = {}

	function CustomPresets.DoSomething(doTheThing: boolean): (Sound) -> ()
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
local Presets = {}

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Presets

	Combines presets together into 1 reusable preset.

	:::info
	Presets are applied in sequence from first to last.
	:::

	```lua
	local myCombinedPreset = VluxySF.Presets.Combine(
		VluxySF.Presets.NaturalPlaybackJitter(1, 0.1),
		VluxySF.Presets.NaturalVolumeJitter(0.7, 0.15)
	)

	local myCombinedPreset2 = VluxySF.Presets.Combine(
		myCombinedPreset,
		VluxySF.Presets.Parent(workspace.Sounds)
	)

	local sound1 = VluxySF.Fetch("mySound1", nil, myCombinedPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myCombinedPreset)
	
	local sound3 = VluxySF.Fetch("mySound3", nil, myCombinedPreset2)
	local sound4 = VluxySF.Fetch("mySound4", nil, myCombinedPreset2)
	```

	@param ... (Sound) -> () -- Your Preset Closures to combine.

	@return (Sound) -> () -- Closure of the combined presets.
]=]
function Presets.Combine(...: (Sound) -> ()): (Sound) -> ()
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
	@within Presets

	Sets the parent of a sound.

	```lua
	local myPreset = VluxySF.Presets.Parent(workspace.Sounds)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param parent Instance -- The parent to set the sound too.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.Parent(parent: Instance): (Sound) -> ()
	return function(sound: Sound)
		sound.Parent = parent
	end
end

--[=[
	@within Presets

	Sets the volume of a sound.

	```lua
	local myPreset = VluxySF.Presets.Volume(0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param volume number -- The volume to set the sound too.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.Volume(volume: number): (Sound) -> ()
	return function(sound: Sound)
		sound.Volume = volume
	end
end

--[=[
	@within Presets

	Sets the playback speed of a sound.

	```lua
	local myPreset = VluxySF.Presets.PlaybackSpeed(1.3)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param speed number -- The playback speed to set for the sound too.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.PlaybackSpeed(speed: number): (Sound) -> ()
	return function(sound: Sound)
		sound.PlaybackSpeed = speed
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Presets

	Uses `Jitter.Natural` to apply a natural jitter to the volume of the sound.

	```lua
	local myPreset = VluxySF.Presets.NaturalVolumeJitter(0.8, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.NaturalVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Natural(center or 0.5, spread or 0.1)

	return function(sound: Sound)
		sound.Volume = jitter()
	end
end

--[=[
	@within Presets

	Uses `Jitter.Natural` to apply a natural jitter to the playback speed of the sound.

	```lua
	local myPreset = VluxySF.Presets.NaturalPlaybackJitter(1, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.NaturalPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Natural(center or 1, spread or 0.1)

	return function(sound: Sound)
		sound.PlaybackSpeed = jitter()
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Presets

	Uses `Jitter.Uniform` to apply a random jitter to the volume of the sound.

	```lua
	local myPreset = VluxySF.Presets.RandomVolumeJitter(0.8, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.RandomVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Uniform(center or 0.5, spread or 0.1)

	return function(sound: Sound)
		sound.Volume = jitter()
	end
end

--[=[
	@within Presets

	Uses `Jitter.Uniform` to apply a random jitter to the playback speed of the sound.

	```lua
	local myPreset = VluxySF.Presets.RandomPlaybackJitter(1, 0.1)

	local sound1 = VluxySF.Fetch("mySound1", nil, myPreset)
	local sound2 = VluxySF.Fetch("mySound2", nil, myPreset)
	local sound3 = VluxySF.Fetch("mySound3", nil, myPreset)
	```

	@param center number? -- The central value of the jitter.
	@param spread number? -- The spread of the jitter.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.RandomPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	local jitter = Jitter.Uniform(center or 1, spread or 0.1)

	return function(sound: Sound)
		sound.PlaybackSpeed = jitter()
	end
end

------------------------------------------------------------------------------------------------------------------------

return Presets
