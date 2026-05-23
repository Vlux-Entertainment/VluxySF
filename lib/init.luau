--!strict

local Debris = game:GetService("Debris")

local tools = script.Tools
local utility = script.Utility
local internals = script.Internals
local sections = script.Sections

local FormatMessage = require(utility.FormatMessage)
local Tables = require(utility.Tables)

local Converters = require(tools.Converters)

local Conversions = require(sections.Conversions)
local Jitter = require(sections.Jitter)
local Misc = require(sections.Misc)
local SoundPresets = require(sections.SoundPresets)

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

----------------------------------------------------------------------------------------------------------------

local initializedEvent = Instance.new("BindableEvent")
initializedEvent.Parent = script

local isInitialized = false

local schemaFailCheck = function()
	if isInitialized then
		return
	end

	FormatMessage.Error("Sound schema is not initialized yet! You need to wait before you can use this function!")
end

----------------------------------------------------------------------------------------------------------------

--[=[
	@class VluxySF

	@client
	@server

	VluxySoundFactory is a sound management system designed to simplify the process of creating, organizing, and playing sounds in Roblox.
	
	It allows developers to define sounds and their properties in a structured way, supports sound groups for better organization, and includes functionality for adding variance to sound playback to make it less repetitive.

	The Below sections are part of the VluxySF module.
]=]
local Sounds = {}

----------------------------------------------------------------------------------------------------------------
--SCHEMA_STARTUP------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class Startup

	Functions for checking the initialization status of the sound schema and waiting for it to be ready.
]=]
Sounds.Startup = {}

--[=[
	@within Startup

	@server

	@param soundFolder Configuration | Folder -- Folder containing all sound data

	Injects the source folder used to build sound data and sets up server-side structures.

	This should only run once!
]=]
function Sounds.Startup.InitServer(soundFolder: Configuration | Folder)
	local Server = require(internals.Server)
	Server._initServer(soundFolder)

	--fetch
	soundSchema = Server.GetSoundSchema()
	Tables.DeepFreeze(soundSchema)

	isInitialized = true
	initializedEvent:Fire()
end

--[=[
	@within Startup

	@client

	@yields

	@param timeout number? -- optional timeout for preloading sounds, default is 5 seconds

	Sets up client-side structures and retrieves sound data from the server.

	This should only run once!
]=]
function Sounds.Startup.InitClient(timeout: number?)
	local Client = require(internals.Client)
	Client._initClient(timeout)

	--fetch
	soundSchema = Client.GetSoundSchema()
	Tables.DeepFreeze(soundSchema)

	isInitialized = true
	initializedEvent:Fire()

	FormatMessage.Print("The sound schema has been initialized and is ready for use!")
end

--[=[
	@within Startup

	@return boolean -- Whether the sound schema has been initialized.

	Checks if the sound schema has been initialized.
]=]
function Sounds.Startup.IsInitialized(): boolean
	return isInitialized
end

--[=[ 
	@within Startup

	@yields

	@return boolean -- Whether the sound schema is ready for use.

	Waits until the sound schema is initialized and ready for use.

	If you know that your code will execute after the schema is loaded then this is not needed.
]=]
function Sounds.Startup.WaitForSchema()
	if isInitialized then
		return
	end

	initializedEvent.Event:Wait()
end

----------------------------------------------------------------------------------------------------------------
--SOUND_DEFINITIONS_TABLES--------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class Schema

	@tag RequiresSchema

	Functions for accessing the sound schema and its data.
]=]
Sounds.Schema = {}

--[=[
	@within Schema

	@return SoundSchema -- The internal sound schema used by the system.

	Provides access to the internal sound schema.
]=]
function Sounds.Schema.Get(): SoundSchema
	schemaFailCheck()

	return soundSchema
end

--[=[
	@within Schema

	@return SoundDefinitions -- All converted sound data

	Returns all serialized sound data.
]=]
function Sounds.Schema.GetDefinitions(): SoundDefinitions
	schemaFailCheck()

	return soundSchema.SoundDefinitions
end

--[=[
	@within Schema

	@return { string } -- All registered sound locations

	Returns all sound locations.
]=]
function Sounds.Schema.GetLocations(): { string }
	schemaFailCheck()

	local locations = {}

	for location, _ in pairs(soundSchema.SoundDefinitions) do
		table.insert(locations, location)
	end

	return locations
end

----------------------------------------------------------------------------------------------------------------
--SOUND_GROUP_FUNCTIONS-----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class SoundGroups

	@tag RequiresSchema

	Functions for getting and setting the created sound groups.
]=]
Sounds.Groups = {}

--[=[
	@within SoundGroups

	@return SoundGroups -- All sound groups defined in the schema.

	Returns all sound groups defined in the schema.
]=]
function Sounds.Groups.Get(): Types.SoundGroups
	schemaFailCheck()

	return soundSchema.SoundGroups
end

--[=[
	@within SoundGroups

	@param name string -- The name of the sound group to retrieve.

	@return SoundGroup? -- The sound group instance if found, otherwise nil.

	Retrieves a sound group instance by its name.
]=]
function Sounds.Groups.GetByName(name: string): SoundGroup?
	schemaFailCheck()

	return soundSchema.SoundGroups[name]
end

--[=[
	@within SoundGroups

	@return { string } -- A list of all sound group names defined in the schema.

	Returns a list of all sound group names defined in the schema.
]=]
function Sounds.Groups.GetNames(): { string }
	schemaFailCheck()

	local names = {}

	for name, _ in pairs(soundSchema.SoundGroups) do
		table.insert(names, name)
	end

	return names
end

--[=[
	@within SoundGroups

	@param volumes { [string]: number } -- A dictionary mapping sound group names to their desired volume levels.

	Sets the volume levels for multiple sound groups at once based on the provided dictionary of group names and volume values.
]=]
function Sounds.Groups.SetVolumes(volumes: { [string]: number })
	schemaFailCheck()

	for groupName, volume in pairs(volumes) do
		local group = Sounds.Groups.GetByName(groupName)

		if not group then
			warn(`VluxySF: Attempted to set volume for sound group '{groupName}', but it does not exist in schema!`)
			continue
		end

		group.Volume = volume
	end
end

----------------------------------------------------------------------------------------------------------------
--SOUND_FETCHING------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@within VluxySF

	@param name string -- The name of the `SoundDefinition`.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param preset (Sound) -> ()? -- Function to preconfigure the sound.

	@return Sound? -- The fetched sound instance if found, otherwise nil.
	
	Finds the specified `SoundDefinition` and gives back a playable `Sound` if it exists.
]=]
function Sounds.Fetch(
	name: GeneratedSoundNames,
	parent: Instance?,
	preset: (Sound) -> ()?
): Types.SoundDefinitionInstanced?
	schemaFailCheck()

	local definition = soundSchema.SoundDefinitions[name]
	if not definition then
		FormatMessage.Warn(`Sound with name '{name}' was not found in schema!`)
		return nil
	end

	local sound = Converters.DefinitionToSound(definition)

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
	@param preset (Sound) -> ()? -- A callback function to execute before the sound plays.
	@param waitOnLoad boolean? -- Whether to wait for the sound to load before playing. Always runs on a separate thread.

	@return Sound? -- The fetched sound instance if found, otherwise nil.

	Fetches a sound, sets it up for one-time playback, and optionally waits for it to load before playing. The sound will be automatically cleaned up after it finishes playing.
]=]
function Sounds.FetchPlayOnce(
	name: GeneratedSoundNames,
	parent: Instance?,
	preset: (Sound) -> ()?,
	waitOnLoad: boolean?
): () -> ()
	schemaFailCheck()

	local sound = Sounds.Fetch(name, parent, preset)

	if not sound then
		return function() end
	end
	sound.Looped = false

	task.spawn(function()
		if waitOnLoad and not sound.IsLoaded then
			sound.Loaded:Wait()
		end

		sound.Ended:Connect(function()
			sound:Destroy()
		end)

		sound:Play()
	end)

	return function()
		if not sound then
			return
		end

		sound:Destroy()
	end
end

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
