--!strict
local RunService = game:GetService("RunService")

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

----------------------------------------------------------------------------------------------------------------

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

local clientFailCheck = function()
	if RunService:IsClient() then
		return
	end

	FormatMessage.Error("Attempted to run a client-only function on the server!", 3)
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

	`VluxySoundFactory` is a sound management system designed to simplify the process of dealing with sounds as a scripter.
	It primarily tries to make fetching your sounds as easy as possible and comes with some memory saving features.
	It also comes with some extra features like jittering and presets.
]=]
local Sounds = {}

----------------------------------------------------------------------------------------------------------------
--SOUND_FETCHING------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@within VluxySF

	@tag RequiresSchema

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the sound.
	@param preset (Sound) -> ()? -- `Preset` to apply.

	@return Sound -- The fetched sound instance.
	
	Finds the specified `SoundDefinition` and gives back a `Sound`. If somthing goes wrong a `Blank Sound` is returned instead.

	:::info
	- If a sound is `Preloaded` it is instead `Cloned` from the preloadFolder
	- If a sound is `Warmed` it is instead `Cloned` from the warmed cache.
	:::

	:::warning
	If the sound is not preloaded or warmed it may take a moment to fetch and load as it needs to be created first.
	:::
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

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset (Sound) -> ()? -- `Preset` to apply.

	@return Sound? -- The fetched `Sound` instance if success.

	Similar to `VluxySF.Fetch` but will not return a `Blank Sound` on fail.
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

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset (Sound) -> ()? -- `Preset` to apply.
	@param waitOnLoad boolean? -- Wait for the `Sound` to load? Always separate thread.

	@return () -> () -- Cleanup function.

	Plays a `OneShot` `Sound` and cleans up after playing.
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

	Functions for initializing the library and making sure its safe to use the `Schema`.

	:::warning
	Some functions in this library cannot run until you wait for the schema to be initialized.
	:::
]=]
Sounds.Startup = {}

--[=[
	@within Startup

	@server

	@param soundFolder Configuration -- The `SOUNDS Configurartion`.

	Injects the `SOUNDS Configuration` into the library and creates the `Schema`.

	:::info
	- It compiles all the information into `Folders`, `Configurations`,  `Sounds`, `SoundGroups`, and sounds names to `Preload`.
	- The schema is locked once `Start.InitServer` runs. Meaning you cannot add new `Sounds`, `SoundGroups`, etc... to the library.
	:::

	:::danger
	This should only run once!
	:::
]=]
function Sounds.Startup.InitServer(soundFolder: Configuration)
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

	@param timeout number? -- Timeout for waiting on sounds to preload.

	Fetches the `Schema` from the server and preloads all sounds that require it.

	:::danger
	This should only run once!
	:::
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

	@return boolean -- Is initialized?

	Checks if the sound schema has been initialized.
]=]
function Sounds.Startup.IsInitialized(): boolean
	return isInitialized
end

--[=[ 
	@within Startup

	@yields

	Waits until the sound schema is initialized and ready for use.

	:::info
	If you know that your code will execute after the `Schema` is loaded then this is not needed.
	:::
]=]
function Sounds.Startup.WaitForSchema()
	if isInitialized then
		return
	end

	initializedEvent.Event:Wait()
end

--[=[
	@within Startup

	@param finished () -> () -- Callback function to execute when the schema is created.

	@return () -> () -- Cleanup function.

	Alternative to `Startup.WaitForSchema` if you do not want to pause the current block.
]=]
function Sounds.Startup.ConnectForSchema(finished: () -> ()): () -> ()
	if isInitialized then
		local thread = task.spawn(finished)

		return function()
			task.cancel(thread)
		end
	end

	local connection = initializedEvent.Event:Once(finished)

	return function()
		connection:Disconnect()
	end
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
