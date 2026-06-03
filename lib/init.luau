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

local function createSoundsFromName(getDefinition: (string) -> SoundDefinition?, ...: GeneratedSoundNames)
	local sounds: { Sound } = {}

	for _, soundName in ipairs({ ... }) do
		local definition = getDefinition(soundName)
		if not definition then
			continue
		end

		local sound = Converters.DefinitionToSound(definition)
		if not sound then
			continue
		end

		table.insert(sounds, sound)
	end

	return sounds
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
	
	Finds the specified `SoundDefinition` and gives back a `Sound`. If somthing goes wrong a `Blank Sound` is returned instead.

	:::info
	- If a sound is `Preloaded` it is instead `Cloned` from the preloadFolder
	- If a sound is `Warmed` it is instead `Cloned` from the warmed cache.
	:::

	:::warning
	If the sound is not preloaded or warmed it may take a moment to fetch and load as it needs to be created first.
	:::

	```lua
	local mySound = VluxySF.Fetch("MySound")
	mySound.Volume = 0.3

	local echoEffect = mySound.EchoSoundEffect
	if echoEffect then
		echoEffect.WetLevel = 1.3
	end

	mySound:Play()
	```
	
	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the sound.
	@param preset (Sound) -> ()? -- `Preset` to apply.

	@return Sound -- The fetched sound instance.
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

	Similar to `VluxySF.Fetch` but will not return a `Blank Sound` on fail.
	
	```lua
	local mySound = VluxySF.Fetch("MySound")
	
	if mySound then
		mySound.Volume = 0.3

		local echoEffect = mySound.EchoSoundEffect
		if echoEffect then
			echoEffect.WetLevel = 1.3
		end

		mySound:Play()
	end
	```

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset (Sound) -> ()? -- `Preset` to apply.

	@return Sound? -- The fetched `Sound` instance if success.
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

	Plays a `OneShot` `Sound` and cleans up after playing.

	```lua
	VluxySF.FetchPlayOnce("MySound")
	```

	@param name string -- The name of the `Sound`.
	@param parent Instance? -- Parent of the `Sound`.
	@param preset (Sound) -> ()? -- `Preset` to apply.
	@param waitOnLoad boolean? -- Wait for the `Sound` to load? Always separate thread.

	@return () -> () -- Cleanup function.
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
--STARTUP-------------------------------------------------------------------------------------------------------
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

	Injects the `SOUNDS Configuration` into the library and creates the `Schema`.

	:::info
	- It compiles all the information into `Folders`, `Configurations`,  `Sounds`, `SoundGroups`, and sounds names to `Preload`.
	- The schema is locked once `Start.InitServer` runs. Meaning you cannot add new `Sounds`, `SoundGroups`, etc... to the library.
	:::

	:::danger
	This should only run once!
	:::

	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")

	local VluxySF = require(ReplicatedStorage.VluxySF)

	local soundConfig = ServerStorage:FindFirstChild("SOUNDS")

	VluxySF.Startup.InitServer(soundConfig)
	```

	@param soundFolder Configuration -- The `SOUNDS Configurartion`.
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

	Fetches the `Schema` from the server and preloads all sounds that require it.

	:::danger
	This should only run once!
	:::

	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local VluxySF = require(ReplicatedStorage.VluxySF)

	local timeout = 4

	VluxySF.Startup.InitClient(timeout)
	```

	@param timeout number? -- Timeout for waiting on sounds to preload.
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

	Checks if the sound schema has been initialized.

	```lua
	print(VluxySF.Startup.IsInitialized())
	```

	@return boolean -- Is initialized?
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

	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local VluxySF = require(ReplicatedStorage.VluxySF)

	VluxySF.Startup.WaitForSchema() --yields

	VluxySF.FetchPlayOnce("MySound")
	```
]=]
function Sounds.Startup.WaitForSchema()
	if isInitialized then
		return
	end

	initializedEvent.Event:Wait()
end

--[=[
	@within Startup

	Alternative to `Startup.WaitForSchema` if you do not want to pause the current block.

	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local VluxySF = require(ReplicatedStorage.VluxySF)

	VluxySF.Startup.ConnectForSchema(function()
		VluxySF.FetchPlayOnce("MySound")
	end)

	--doesn't yield down here!
	```

	@param finished () -> () -- Callback function to execute when the schema is created.

	@return () -> () -- Cleanup function.
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
--DEFINITIONS---------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

--[=[
	@class Schema

	@tag RequiresSchema

	Functions for accessing the sound schema and its data.
]=]
Sounds.Schema = {}

--[=[
	@within Schema

	The full `Schema` used internally by the library.

	```lua
	print(VluxySF.Schema.Get())
	```

	@return SoundSchema -- The internal sound schema used by the system.
]=]
function Sounds.Schema.Get(): Types.SoundSchema
	schemaFailCheck()

	return soundSchema
end

--[=[
	@within Schema

	Returns all `SoundDefinitions` in the `Schema`.

	```lua
	print(VluxySF.Schema.GetDefinitions())
	```

	@return SoundDefinitions -- All converted sound data
]=]
function Sounds.Schema.GetDefinitions(): Types.SoundDefinitions
	schemaFailCheck()

	return soundSchema.SoundDefinitions
end

--[=[
	@within Schema

	Retrieves a `SoundDefinition` from the `Schema` based on its name.

	```lua
	print(VluxySF.Schema.GetDefinition("MySound"))
	```

	@param definitionName string -- The name of the sound definition to retrieve.

	@return SoundDefinition? -- The SoundDefinition associated with the provided name.
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

	Returns all sound names in the library.

	```lua
	print(VluxySF.Schema.GetNames())
	```

	@return { string } -- All registered sound names.
]=]
function Sounds.Schema.GetNames(): { string }
	schemaFailCheck()

	local names = {}

	for name, _ in pairs(soundSchema.SoundDefinitions) do
		table.insert(names, name)
	end

	return names
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

	Functions for adjusting `SoundGroups` in the schema.
]=]
Sounds.Groups = {}

--[=[
	@within SoundGroups

	Returns the `SoundGroups` registerd in the `Schema`.

	```lua
	print(VluxySF.Groups.Get())
	```

	@return SoundGroups -- Dictionary of `SoundGroups`.
]=]
function Sounds.Groups.Get(): Types.SoundGroups
	schemaFailCheck()

	return soundSchema.SoundGroups
end

--[=[
	@within SoundGroups

	Finds a `SoundGroup` by name.

	```lua
	local gameSoundGroup = VluxySF.Groups.GetByName("GAME")

	if gameSoundGroup then
		gameSoundGroup.Volume = 0.3
	end
	```

	@param name string -- Name of the `SoundGroup`.

	@return SoundGroup? -- `SoundGroup` if it exists.
]=]
function Sounds.Groups.GetByName(name: string): SoundGroup?
	schemaFailCheck()

	return soundSchema.SoundGroups[name]
end

--[=[
	@within SoundGroups

	Gets an arrray of all `SoundGroup` names within the main group.

	```lua
	print(VluxySF.Groups.GetNames())
	```

	@return { string } -- Array of `SoundGroup` names.
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

	Sets the volume of the main `SoundGroup` that all other groups derive from.

	```lua
	VluxySF.Groups.SetMainVolume(0.3)
	```

	@param mainVolume number -- Volume level to set.
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

	Sets Volumes to the provided levels.

	:::tip
	MainVolume and the individual volume elements are optional when using `SoundGroups.SetVolumes`.
	:::

	```lua
	local mainVolume = 1
	local volumes = {
		["GAME"] = 0.7,
		["UI"] = 0.5,
	}
	
	VluxySF.Groups.SetVolumes(mainVolume, volumes)
	```

	@param mainVolume number? --  -- Main volume level to set.
	@param volumes { [string]: number } -- Dictionary of the volumes to adjust.
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

	Functions for `Preloading` your `Sounds`.
]=]
Sounds.Preload = {}

--[=[
	@within Preload

	Gets a dictionary of all `Preloaded` `Sounds` including entries added after startup.

	```lua
	print(VluxySF.Preload.Get())
	```

	@return { [string]: Sound } -- Dictionary of all `Preloaded` `Sounds`.
]=]
function Sounds.Preload.Get(): { [string]: Sound }
	schemaFailCheck()
	clientFailCheck()

	return Preloading.GetNames()
end

--[=[
	@within Preload

	Preloads the provided variables and stores them internally.

	:::info
	- If a `Sound` is `Preloaded` `Warming` it will have no effect.
	:::

	```lua

	local sound1 = ...
	local sound2 = ...
	local sound3 = ...

	local soundDefinition1 = ...
	local soundDefinition2 = ...

	local soundName1 = "MySound1"
	local soundName2 = "MySound2"

	Preload.Selected(
		sound1,
		sound2,
		sound3,
		soundDefinition1,
		soundDefinition2,
		soundName1,
		soundName2
	)
	```

	@param ... string -- Names to `Preload`.
]=]
function Sounds.Preload.Selected(...: GeneratedSoundNames)
	schemaFailCheck()
	clientFailCheck()

	local sounds = createSoundsFromName(Sounds.Schema.GetDefinition, ...)
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

	Returns a hash of the current sounds that are warmed.

	```lua
	print(VluxySF.Cache.Get())
	```

	@return { [string]: Sound } -- The current sounds being Warmed.
]=]
function Sounds.Cache.Get(): { [string]: Sound }
	schemaFailCheck()
	clientFailCheck()

	return WarmCache.GetSounds()
end

--[=[
	@within Cache

	Tells you if a sound from its name is currently warmed.

	```lua
	print(VluxySF.Cache.IsWarmed("MySound"))
	```

	@param soundName string -- Name of the `Sound`.

	@return boolean -- Is that sound warmed?
]=]
function Sounds.Cache.IsWarmed(soundName: string): boolean
	schemaFailCheck()
	clientFailCheck()

	return WarmCache.IsWarmed(soundName)
end

--[=[
	@within Cache

	Loads the `Sound` to the Client. If the the same `Sound` is fetched it will instead `Clone` from it.

	:::warning
	You should only warm if you need a sound to play without a delay or to play without fail but dont plan to constantly use it.
	:::

	:::tip
	You can Warm at the top of a script or a seperate script if the sound you play is in a connection or function that gets called later.
		Some examples include loading a map and its sounds in. Maybe warming the sounds when first loading the map is a good idea!?
	:::

	```lua
	VluxySF.Cache.Warm("MySound") --now if its used later on it should be ready to play.

	--do stuff

	task.wait(5)

	--do stuff

	VluxySF.FetchplayOnce("MySound") --should play without delay now
	```

	@param ... string -- Names of the `Sounds`.
]=]
function Sounds.Cache.Warm(...: GeneratedSoundNames)
	schemaFailCheck()
	clientFailCheck()

	local sounds = createSoundsFromName(Sounds.Schema.GetDefinition, ...)
	for _, sound in ipairs(sounds) do
		WarmCache.SetSound(soundSchema.WarmedSounds, sound)
	end
end

--[=[
	@within Cache

	If a `Sound` with that name is currently warmed it is removed it from the cache.

	:::info
	Removing a sound from the cache does not garentee that it will be unloaded. 
	If you still have Sounds with the same Id it will still be in memmory.
	:::

	```lua

	VluxySF.Cache.Warm("MySound")

	local onPlay = Instance.new("BindableEvent")
	local myWarmedSound = ...

	local function playSound()
		myWarmedSound:Play() --plays without delay
	end
	OnPlay.Event:Connect(playSound)

	OnPlay.Destroying:Connect(function()
		myWarmedSound:Destroy() --clean up our sound
		VluxySF.Cache.Chill("MySound") -- now the sound isn't warmed
	end)


	--Now if OnPlay is destroyed it wont be warmed anymore.
	--So, if the soundId isnt used anywhere else it will be removed from memmory.
	```

	@param ... string -- Names of the `Sounds`.
]=]
function Sounds.Cache.Chill(...: GeneratedSoundNames)
	schemaFailCheck()
	clientFailCheck()

	for _, soundName in ipairs({ ... }) do
		WarmCache.RemoveSound(soundName)
	end
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

	Converts a `Sound` into a `SoundDefinition`.

	```lua
	local mySound = ...

	local soundDefinition = VluxySF.Conversions.ToDefinition(mySound)

	print(soundDefinition)
	```

	@param sound -- The `Sound` to convert.

	@return SoundDefinition -- The resulting `SoundDefinition`.
]=]
function Sounds.Conversions.ToDefinition(sound: Sound): Types.SoundDefinition
	return Converters.SoundToDefinition(sound)
end

--[=[
	@within Conversions

	Converts a `SoundDefinition` into a `Sound`.

	```lua
	local soundDefinition = {
		Properties = {
			Name = "MySound",
			SoundId = "rbxassetid://123456789",
			Volume = 0.5,
			SoundGroup = "GAME",
		},
		Effects = {},
		EffectCount = 0
	}

	local mySound = VluxySF.Conversions.FromDefinition(soundDefinition)

	mySound:Play()
	```

	@param definition SoundDefinition -- The `SoundDefinition` to convert.

	@return Sound -- The resulting `Sound`.
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
