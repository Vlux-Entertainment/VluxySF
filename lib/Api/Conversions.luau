--!strict
--!optimize 2

local Converters = require(script.Parent.Parent.Core.Converters)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Types = require(script.Parent.Parent.Types)

--[=[
	@class Conversions

	Converts between `Sounds` and `SoundDefinitions`. These do not need the schema, so they work before startup.

	Neither function throws on bad input: it warns and returns a blank definition or a silent blank `Sound` named
	`VluxySF_Blank_Sound` instead.
]=]
local Conversions = {}

--[=[
	@within Conversions

	Turns a `Sound` and its `SoundEffect` children into a `SoundDefinition`. Only properties that differ from the
	defaults are kept, plus the name. Playback state (`Playing`, `TimePosition`) is never kept.

	```lua
	local definition = VluxySF.Conversions.ToDefinition(workspace.MySound)

	print(definition.Properties.Volume)
	```

	@param sound Sound -- The `Sound` to convert. Anything that is not a `Sound` warns and gives a blank definition.

	@return SoundDefinition -- The definition.
]=]
function Conversions.ToDefinition(sound: Sound): Types.SoundDefinition
	if typeof(sound) ~= "Instance" or not sound:IsA("Sound") then
		FormatMessage.Warn(
			`Conversions.ToDefinition expected a Sound, got {typeof(sound)}. A blank definition was returned instead.`
		)

		return Converters.NewBlankDefinition()
	end

	return Converters.SoundToDefinition(sound)
end

--[=[
	@within Conversions

	Builds a new, unparented `Sound` from a `SoundDefinition`. Effects are parented under their class names. Each
	effect carries its class name as `Name`. With no effects, pass an empty `Effects` table and an `EffectsCount` of 0.

	```lua
	local sound = VluxySF.Conversions.FromDefinition({
		Properties = {
			Name = "MySound",
			SoundId = "rbxassetid://123456789",
			Volume = 0.5,
		},
		Effects = {
			EchoSoundEffect = { Name = "EchoSoundEffect", Delay = 0.5 },
		},
		EffectsCount = 1,
	})

	sound.Parent = workspace
	sound:Play()
	```

	@param definition SoundDefinition -- The definition to build. Anything without a `Properties` table warns and
	gives a blank `Sound`.

	@return Sound -- The new `Sound`.
]=]
function Conversions.FromDefinition(definition: Types.SoundDefinition): Types.SoundDefinitionInstanced
	if type(definition) ~= "table" or type((definition :: any).Properties) ~= "table" then
		FormatMessage.Warn(
			`Conversions.FromDefinition expected a definition with a Properties table, got {typeof(definition)}. A blank sound was returned instead.`
		)

		return Converters.DefinitionToSound(Converters.NewBlankDefinition())
	end

	return Converters.DefinitionToSound(definition)
end

return Conversions
