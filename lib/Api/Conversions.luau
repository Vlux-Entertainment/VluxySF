--!strict
--!optimize 2

local Converters = require(script.Parent.Parent.Core.Converters)
local Types = require(script.Parent.Parent.Types)

--[=[
	@class Conversions

	Converts between `Sounds` and `SoundDefinitions`. These do not need the schema, so they work before startup.
]=]
local Conversions = {}

--[=[
	@within Conversions

	Turns a `Sound` and its `SoundEffect` children into a `SoundDefinition`. Only properties that differ from the
	defaults are kept, plus the name.

	```lua
	local definition = VluxySF.Conversions.ToDefinition(workspace.MySound)

	print(definition.Properties.Volume)
	```

	@param sound Sound -- The `Sound` to convert.

	@return SoundDefinition -- The definition.
]=]
function Conversions.ToDefinition(sound: Sound): Types.SoundDefinition
	return Converters.SoundToDefinition(sound)
end

--[=[
	@within Conversions

	Builds a new, unparented `Sound` from a `SoundDefinition`. Effects are parented under their class names.

	```lua
	local sound = VluxySF.Conversions.FromDefinition({
		Properties = {
			Name = "MySound",
			SoundId = "rbxassetid://123456789",
			Volume = 0.5,
		},
		Effects = {
			EchoSoundEffect = { Delay = 0.5 },
		},
		EffectsCount = 1,
	})

	sound.Parent = workspace
	sound:Play()
	```

	@param definition SoundDefinition -- The definition to build.

	@return Sound -- The new `Sound`.
]=]
function Conversions.FromDefinition(definition: Types.SoundDefinition): Types.SoundDefinitionInstanced
	return Converters.DefinitionToSound(definition)
end

return Conversions
