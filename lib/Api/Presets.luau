--!strict
--!optimize 2

local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Jitter = require(script.Parent.Jitter)

--What a builder returns when it was given a bad argument: the warning is printed where the mistake was made, and the
--fetches that use the preset go on as if there were no preset.
local function doNothing(_sound: Sound) end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--Returns true when the argument is usable, otherwise warns.
local function checkNumber(functionName: string, argumentName: string, value: any): boolean
	if isFinite(value) then
		return true
	end

	FormatMessage.Warn(
		`Presets.{functionName} {argumentName} must be a number, got {tostring(value)}. The preset does nothing.`
	)

	return false
end

--Like checkNumber, for the optional center and spread of the jitter presets. nil means the default.
local function checkOptionalNumber(functionName: string, argumentName: string, value: any): boolean
	return value == nil or checkNumber(functionName, argumentName, value)
end

local function setParent(sound: Sound, parent: Instance)
	sound.Parent = parent
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@class Presets

	Presets are functions that adjust a `Sound` as it is fetched, before it is parented, for property values you set
	over and over.

	:::info
	- Presets are closures that get passed to your fetching functions.
	- You can create your own presets and combine them with the built in ones.
	- When a preset runs everything should be cleaned up before exiting the function block.
	- A built-in preset never throws. A builder given a bad argument warns right away and returns a preset that does
	  nothing, so the sounds that use it still play.
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
	Presets are applied in sequence from first to last. An argument that is not a function warns and is left out.
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
	local presets: { (Sound) -> () } = {}

	--counted with select so a nil in the middle is reported instead of cutting the list short
	for index = 1, select("#", ...) do
		local preset = (select(index, ...))

		if type(preset) == "function" then
			table.insert(presets, preset)
		else
			FormatMessage.Warn(
				`Presets.Combine argument {index} must be a preset function, got {tostring(preset)}. It was left out.`
			)
		end
	end

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
	if typeof(parent) ~= "Instance" then
		FormatMessage.Warn(
			`Presets.Parent parent must be an Instance, got {tostring(parent)}. The preset does nothing.`
		)

		return doNothing
	end

	return function(sound: Sound)
		--the parent can be destroyed or locked by the time a sound is fetched; the sound then stays unparented and the
		--fetch places it like any other unparented sound
		local success, reason = pcall(setParent :: any, sound, parent)
		if not success then
			FormatMessage.Warn(`Presets.Parent could not parent "{sound.Name}" to {parent:GetFullName()}: {reason}`)
		end
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
	if not checkNumber("Volume", "volume", volume) then
		return doNothing
	end

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
	if not checkNumber("PlaybackSpeed", "speed", speed) then
		return doNothing
	end

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

	@param center number? -- The central value of the jitter. Default is 0.5.
	@param spread number? -- The spread of the jitter. Default is 0.1.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.NaturalVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	if
		not checkOptionalNumber("NaturalVolumeJitter", "center", center)
		or not checkOptionalNumber("NaturalVolumeJitter", "spread", spread)
	then
		return doNothing
	end

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

	@param center number? -- The central value of the jitter. Default is 1.
	@param spread number? -- The spread of the jitter. Default is 0.1.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.NaturalPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	if
		not checkOptionalNumber("NaturalPlaybackJitter", "center", center)
		or not checkOptionalNumber("NaturalPlaybackJitter", "spread", spread)
	then
		return doNothing
	end

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

	@param center number? -- The central value of the jitter. Default is 0.5.
	@param spread number? -- The spread of the jitter. Default is 0.1.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.RandomVolumeJitter(center: number?, spread: number?): (Sound) -> ()
	if
		not checkOptionalNumber("RandomVolumeJitter", "center", center)
		or not checkOptionalNumber("RandomVolumeJitter", "spread", spread)
	then
		return doNothing
	end

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

	@param center number? -- The central value of the jitter. Default is 1.
	@param spread number? -- The spread of the jitter. Default is 0.1.

	@return (Sound) -> () -- Closure of the preset.
]=]
function Presets.RandomPlaybackJitter(center: number?, spread: number?): (Sound) -> ()
	if
		not checkOptionalNumber("RandomPlaybackJitter", "center", center)
		or not checkOptionalNumber("RandomPlaybackJitter", "spread", spread)
	then
		return doNothing
	end

	local jitter = Jitter.Uniform(center or 1, spread or 0.1)

	return function(sound: Sound)
		sound.PlaybackSpeed = jitter()
	end
end

------------------------------------------------------------------------------------------------------------------------

return Presets
