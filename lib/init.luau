--!strict

local tools = script.Tools
local utility = script.Utility
local sections = script.Sections
local internals = script.Internals

local FormatMessage = require(utility.FormatMessage)
local Tables = require(utility.Tables)

local Converters = require(tools.Converters)
local Preloading = require(tools.Preloading)
local WarmCache = require(tools.WarmCache)

local Jitter = require(sections.Jitter)
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

local initializedEvent = Instance.new("BindableEvent")
initializedEvent.Name = "Initialized"
initializedEvent.Parent = script

local isInitialized = false

local soundSchema: Types.SoundSchema = nil

----------------------------------------------------------------------------------------------------------------

local blankSoundSchema = {
	Properties = {
		Name = "VluxySF_Blank_Sound",
	},
	Effects = {},
} :: SoundDefinition

local function makeBlankSound(soundName: string, shouldWarn: boolean): Sound
	if shouldWarn then
		FormatMessage.Warn(
			`Sound with name '{soundName}' could not be found or created! Returning blank sound instead!`
		)
	end

	return Converters.DefinitionToSound(blankSoundSchema)
end

----------------------------------------------------------------------------------------------------------------

local schemaFailCheck = function()
	if isInitialized then
		return
	end

	FormatMessage.Error("Sound schema is not initialized yet! You need to wait before you can use this function!", 3)
end

----------------------------------------------------------------------------------------------------------------

local function grabPremadeSound(soundName: string): Sound?
	--preload
	local premadeSound: Sound? = Preloading.GetSound(soundName)
	if premadeSound then
		return premadeSound:Clone()
	end

	--warmed
	premadeSound = WarmCache.GetSound(soundName)
	if premadeSound then
		return premadeSound:Clone()
	end

	return nil
end

local function createSound(soundName: string): Sound?
	local definition = soundSchema.SoundDefinitions[soundName]
	if not definition then
		FormatMessage.Warn(`Sound with name '{soundName}' was not found in schema!`)

		return nil
	end

	local sound = Converters.DefinitionToSound(definition)
	if not sound then
		FormatMessage.Warn(`Sound with name '{soundName}' failed to convert to a Sound instance!`)

		return nil
	end

	return sound
end

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
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

	@tag RequiresSchema

	@param name string -- The name of the `SoundDefinition`.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param preset (Sound) -> ()? -- Function to preconfigure the sound.

	@return Sound -- The fetched sound instance.
	
	Finds the specified `SoundDefinition` and gives back a playable Sound. If it doesnt exist a blank sound is returned.
]=]
function Sounds.Fetch(name: GeneratedSoundNames, parent: Instance?, preset: (Sound) -> ()?): SoundDefinitionInstanced
	schemaFailCheck()

	local sound = grabPremadeSound(name) or createSound(name) or makeBlankSound(name, true)
	sound.Parent = game

	local oldParent = sound.Parent
	if preset then
		preset(sound)
	end

	if parent then
		sound.Parent = parent
	elseif sound.Parent == oldParent then
		sound.Parent = soundSchema.UnattachedSounds
	end

	return sound :: SoundDefinitionInstanced
end

--[=[
	@within VluxySF

	@tag RequiresSchema

	@param name string -- The name of the `SoundDefinition`.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param preset (Sound) -> ()? -- Function to preconfigure the sound.

	@return Sound? -- The fetched sound instance if found, otherwise nil.

	Just like `VluxySF.Fetch` but will only give back a sound if it can find it.
]=]
function Sounds.FetchStrict(
	name: GeneratedSoundNames,
	parent: Instance?,
	preset: (Sound) -> ()?
): SoundDefinitionInstanced?
	schemaFailCheck()

	local sound = grabPremadeSound(name) or createSound(name)
	if not sound then
		FormatMessage.Warn(`Sound with name '{name}' could not be found or created!`)

		return nil
	end

	sound.Parent = game

	local oldParent = sound.Parent
	if preset then
		preset(sound)
	end

	if parent then
		sound.Parent = parent
	elseif sound.Parent == oldParent then
		sound.Parent = soundSchema.UnattachedSounds
	end

	return sound :: SoundDefinitionInstanced
end

--[=[
	@within VluxySF

	@tag RequiresSchema

	@param name string -- The name of the sound definition to fetch.
	@param parent Instance? -- Optional parent for the fetched sound.
	@param preset (Sound) -> ()? -- A callback function to execute before the sound plays.
	@param waitOnLoad boolean? -- Whether to wait for the sound to load before playing. Always runs on a separate thread.

	@return Sound? -- The fetched sound instance if found, otherwise nil.

	Fetches a sound, sets it up for one-time playback. The sound will be automatically cleaned up after it finishes playing.
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
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

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
end

------------------------------------------------------------------------------------------------------------

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
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--SOUND_DEFINITIONS---------------------------------------------------------------------------------------------
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
function Sounds.Schema.Get(): Types.SoundSchema
	schemaFailCheck()

	return soundSchema
end

--[=[
	@within Schema

	@return SoundDefinitions -- All converted sound data

	Returns all serialized sound data.
]=]
function Sounds.Schema.GetDefinitions(): Types.SoundDefinitions
	schemaFailCheck()

	return soundSchema.SoundDefinitions
end

--[=[
	@within Schema

	@param definitionName string -- The name of the sound definition to retrieve.

	@return SoundDefinition? -- The SoundDefinition associated with the provided name.

	Retrieves a SoundDefinition from the schema based on its name.
]=]
function Sounds.Schema.GetDefinition(definitionName: string): Types.SoundDefinition?
	schemaFailCheck()

	local definition = soundSchema.SoundDefinitions[definitionName]
	if not definition then
		FormatMessage.Warn(`Sound with name '{definitionName}' was not found in schema!`)
	end

	return definition
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
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--SOUND_GROUPS--------------------------------------------------------------------------------------------------
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

----------------------------------------------------------------------------------------------------------------

--[=[
    @within SoundGroups

    @param mainVolume number -- The desired main volume level to set for the "SOUNDS" group.

    Sets the main volume level for the "SOUNDS" group, which can be used as a master volume control for all sounds in that group.
]=]
function Sounds.Groups.SetMainVolume(mainVolume: number)
	schemaFailCheck()

	local soundsGroup = soundSchema.SoundGroupContainer

	if soundsGroup then
		soundsGroup.Volume = mainVolume
	end
end

--[=[
	@within SoundGroups

	@param mainVolume number? -- An optional main volume level to set.
	@param volumes { [string]: number } -- A dictionary mapping sound group names to their desired volume levels.

	Sets the volume levels for multiple sound groups at once based on the provided dictionary of group names and volume values.
]=]
function Sounds.Groups.SetVolumes(mainVolume: number?, volumes: { [string]: number })
	schemaFailCheck()

	if mainVolume then
		Sounds.Groups.SetMainVolume(mainVolume)
	end

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
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--PRELOADING----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class Preload

	@tag RequiresSchema

	@client

	Functions for preloading sounds based on various identifiers such as sound locations.
]=]
Sounds.Preload = {}

--[=[
	@within Preload

	@return { [string]: Sound } -- A table mapping sound names to their corresponding preloaded Sound instances.

	Returns a table of preloaded Sound instances. This is currently not implemented and will return an empty table.
]=]
function Sounds.Preload.Get(): { [string]: Sound }
	schemaFailCheck()

	return Preloading.GetNames()
end

--[=[
	@within Preload

	@param ... string | Sound | Types.SoundDefinition -- Allowed types to preload.

	Preloads the specified sounds, if they were already preloaded the instance is destroyed.
]=]
function Sounds.Preload.Selected(...: string | Sound | Types.SoundDefinition)
	schemaFailCheck()

	local sounds: { Sound } = {}

	for _, soundType in ipairs({ ... }) do
		local sound: Sound? = nil

		if typeof(soundType) == "Instance" and soundType:IsA("Sound") then
			sound = soundType
		elseif typeof(soundType) == "table" then
			sound = Converters.DefinitionToSound(soundType :: Types.SoundDefinition)
		elseif typeof(soundType) == "string" then
			local definition = Sounds.Schema.GetDefinition(soundType)
			if not definition then
				continue
			end

			sound = Converters.DefinitionToSound(definition)
		end

		if not sound then
			continue
		end

		table.insert(sounds, sound)
	end

	Preloading.Selected(soundSchema.PreloadedSounds, table.unpack(sounds))
end

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--WARMING-------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class Cache

	@tag RequiresSchema

	@client

	Functions for warming and chilling sounds.
]=]
Sounds.Cache = {}

--[=[
	@within Cache

	@return { [string]: Sound } -- The current sounds being Warmed.

	Returns a hash of the current sounds that are warmed.
]=]
function Sounds.Cache.Get(): { [string]: Sound }
	schemaFailCheck()

	return WarmCache.GetSounds()
end

--[=[
	@within Cache

	@param soundName string -- Name of the `Sound`.

	@return boolean -- Is that sound warmed?

	Tells you if a sound from its name is currently warmed.
]=]
function Sounds.Cache.IsWarmed(soundName: string): boolean
	schemaFailCheck()

	return WarmCache.IsWarmed(soundName)
end

--[=[
	@within Cache

	@param soundName string -- The name of the `Sound`.

	Loads the `Sound` to the Client. If the the same `Sound` is fetched it will instead `Clone` from it.

	:::warning
	You should only warm if you need a sound to play without a delay or to play without fail but dont plan to constantly use it.
	:::
]=]
function Sounds.Cache.Warm(soundName: GeneratedSoundNames)
	schemaFailCheck()

	local definition = Sounds.Schema.GetDefinition(soundName)
	if not definition then
		return
	end

	local sound = Converters.DefinitionToSound(definition)

	WarmCache.SetSound(soundSchema.WarmedSounds, sound)
end

--[=[
	@within Cache

	@param soundName string -- The name of the `Sound`.

	If a `Sound` with that name is currently warmed it is removed it from the cache.

	:::info
	Removing a sound from the cache does not garentee that it will be unloaded. 
	If you still have Sounds with the same Id it will still be in memmory.
	:::
]=]
function Sounds.Cache.Chill(soundName: GeneratedSoundNames)
	schemaFailCheck()

	WarmCache.RemoveSound(soundName)
end

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--SOUND_CONVERSIONS---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class Conversions
	
	Functions for converting between `Sounds` and `SoundDefinitions`.
]=]
Sounds.Conversions = {}

--[=[
	@within Conversions

	@param sound -- The `Sound` to convert.

	@return SoundDefinition -- The resulting `SoundDefinition`.

	Converts a `Sound` into a `SoundDefinition`.
]=]
function Sounds.Conversions.ToDefinition(sound: Sound): Types.SoundDefinition
	return Converters.SoundToDefinition(sound)
end

--[=[
	@within Conversions

	@param definition SoundDefinition -- The `SoundDefinition` to convert.

	@return Sound -- The resulting `Sound`.

	Converts a `SoundDefinition` into a `Sound`.
]=]
function Sounds.Conversions.FromDefinition(definition: Types.SoundDefinition): Types.SoundDefinitionInstanced
	return Converters.DefinitionToSound(definition)
end

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--PRESETS-------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Presets = SoundPresets

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
--JITTER_FUNCTIONS----------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

Sounds.Jitter = Jitter

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

return Sounds
