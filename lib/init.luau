--!strict

local tools = script.Tools
local utility = script.Utility
local sections = script.Sections

local FormatMessage = require(utility.FormatMessage)

local Converters = require(tools.Converters)

local Conversions = require(sections.Conversions)
local Groups = require(sections.Groups)
local Jitter = require(sections.Jitter)
local Misc = require(sections.Misc)
local Schema = require(sections.Schema)
local SoundPresets = require(sections.SoundPresets)
local Startup = require(sections.Startup)

local GeneratedSoundNames = require(script._vluxysf_sound_name_types)
local Types = require(script.Types)

export type GeneratedSoundNames = GeneratedSoundNames.GeneratedSoundNames

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

export type SoundSchema = Types.SoundSchema

----------------------------------------------------------------------------------------------------------------

export type SoundGroups = Types.SoundGroups

export type SoundDefinitionInstanced = Types.SoundDefinitionInstanced
export type SoundChildrenInstanced = Types.SoundChildrenInstanced

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

export type SoundDefinitions = Types.SoundDefinitions
export type SoundDefinition = Types.SoundDefinition

------------------------------------------------------------------------------------------------------------------------

export type SoundChildrenSerialized = Types.SoundChildrenSerialized

export type SoundSerialized = Types.SoundSerialized

export type ChorusSoundEffectSerialized = Types.ChorusSoundEffectSerialized
export type CompressorSoundEffectSerialized = Types.CompressorSoundEffectSerialized
export type DistortionSoundEffectSerialized = Types.DistortionSoundEffectSerialized
export type EchoSoundEffectSerialized = Types.EchoSoundEffectSerialized
export type EqualizerSoundEffectSerialized = Types.EqualizerSoundEffectSerialized
export type FlangeSoundEffectSerialized = Types.FlangeSoundEffectSerialized
export type PitchShiftSoundEffectSerialized = Types.PitchShiftSoundEffectSerialized
export type ReverbSoundEffectSerialized = Types.ReverbSoundEffectSerialized
export type TremoloSoundEffectSerialized = Types.TremoloSoundEffectSerialized

----------------------------------------------------------------------------------------------------------------

local soundSchema: Types.SoundSchema

local blankSoundSchema = {
	Properties = {
		Name = "VluxySF_Blank_Sound",
	},
	Effects = {},
} :: SoundDefinition

local function makeBlankSound(): Sound
	return Converters.DefinitionToSound(blankSoundSchema)
end

----------------------------------------------------------------------------------------------------------------

Startup._waitForInternalSchema(function(schema: Types.SoundSchema)
	soundSchema = schema
end)

local schemaFailCheck = function()
	if Startup.Startup.IsInitialized() then
		return
	end

	FormatMessage.Error("Sound schema is not initialized yet! You need to wait before you can use this function!", 3)
end

Schema._injectSchemaFailCheck(schemaFailCheck)
Schema._injectSoundSchema(soundSchema)

Groups._injectSchemaFailCheck(schemaFailCheck)
Groups._injectSoundSchema(soundSchema)

----------------------------------------------------------------------------------------------------------------

--[=[
	@class VluxySF

	@client
	@server

	VluxySoundFactory is a sound management system designed to simplify the process of creating, organizing, and playing sounds in Roblox.
]=]
local Sounds = {}

----------------------------------------------------------------------------------------------------------------
--SOUND_FETCHING------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@within VluxySF

	@param name string -- The name of the `SoundDefinition`.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param preset (Sound) -> ()? -- Function to preconfigure the sound.

	@return Sound -- The fetched sound instance.
	
	Finds the specified `SoundDefinition` and gives back a playable `Sound`. If it doesnt exist a blank sound is returned.
]=]
function Sounds.Fetch(name: GeneratedSoundNames, parent: Instance?, preset: (Sound) -> ()?): SoundDefinitionInstanced
	schemaFailCheck()

	local definition = soundSchema.SoundDefinitions[name]
	if not definition then
		FormatMessage.Warn(`Sound with name '{name}' was not found in schema!`)

		return makeBlankSound() :: SoundDefinitionInstanced
	end

	local sound = Converters.DefinitionToSound(definition)
	if not sound then
		FormatMessage.Warn(`Sound with name '{name}' failed to convert to a Sound instance!`)

		return makeBlankSound() :: SoundDefinitionInstanced
	end

	if preset then
		preset(sound)
	end

	sound.Parent = parent or soundSchema.UnattachedSounds

	return sound
end

--[[
	@within VluxySF

	@param name string -- The name of the `SoundDefinition`.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param preset (Sound) -> ()? -- Function to preconfigure the sound.

	@return Sound? -- The fetched sound instance if found, otherwise nil.

	Just like `Sounds.Fetch` but will only give back a sound if it can find it.
]]
function Sounds.FetchStrict(
	name: GeneratedSoundNames,
	parent: Instance?,
	preset: (Sound) -> ()?
): SoundDefinitionInstanced?
	schemaFailCheck()

	local definition = soundSchema.SoundDefinitions[name]
	if not definition then
		FormatMessage.Warn(`Sound with name '{name}' was not found in schema!`)

		return nil
	end

	local sound = Converters.DefinitionToSound(definition)
	if not sound then
		FormatMessage.Warn(`Sound with name '{name}' failed to convert to a Sound instance!`)

		return nil
	end

	if preset then
		preset(sound)
	end

	sound.Parent = parent or soundSchema.UnattachedSounds

	return sound
end

--[=[
	@within VluxySF

	@param name string -- The name of the sound definition to fetch.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param waitOnLoad boolean? -- Whether to wait for the sound to load before playing. Always runs on a separate thread.
	@param preset (Sound) -> ()? -- A callback function to execute before the sound plays.

	@return Sound? -- The fetched sound instance if found, otherwise nil.

	Fetches a sound, sets it up for one-time playback, and optionally waits for it to load before playing. The sound will be automatically cleaned up after it finishes playing.
]=]
function Sounds.FetchPlayOnce(
	name: GeneratedSoundNames,
	parent: Instance?,
	waitOnLoad: boolean?,
	preset: (Sound) -> ()?
): () -> ()
	schemaFailCheck()

	local sound = Sounds.Fetch(name, parent, preset)

	if not sound then
		return function() end
	end
	sound.Looped = false

	local playThread = task.spawn(function()
		if waitOnLoad and not sound.IsLoaded then
			sound.Loaded:Wait()
		end

		sound.Ended:Connect(function()
			sound:Destroy()
		end)

		sound:Play()
	end)

	return function()
		if playThread then
			task.cancel(playThread)
		end
		if sound then
			sound:Destroy()
		end
	end
end

----------------------------------------------------------------------------------------------------------------
--SCHEMA_STARTUP------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Startup = Startup.Startup

----------------------------------------------------------------------------------------------------------------
--SOUND_DEFINITIONS_TABLES--------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Schema = Schema.Schema

----------------------------------------------------------------------------------------------------------------
--SOUND_GROUP_FUNCTIONS-----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Groups = Groups.Groups

----------------------------------------------------------------------------------------------------------------
--SOUND_CONVERSIONS---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Conversions = Conversions

----------------------------------------------------------------------------------------------------------------
--PRESETS-------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Presets = SoundPresets

----------------------------------------------------------------------------------------------------------------
--JITTER_FUNCTIONS----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Jitter = Jitter

----------------------------------------------------------------------------------------------------------------
--MISC----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Misc = Misc

return Sounds
