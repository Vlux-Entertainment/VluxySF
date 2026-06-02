--!strict
--!optimize 2

------------------------------------------------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local library = script.Parent.Parent

local FormatMessage = require(library.Utility.FormatMessage)
local Ratelimit = require(library.Utility.RateLimit)
local RemoteFunction = require(library.Utility.RemoteFunction)

local Converters = require(library.Tools.Converters)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------------------

local soundRequest = RemoteFunction.new("SoundRequest")

local preloadSoundsFolder = Instance.new("Configuration")
preloadSoundsFolder.Name = "PreloadSounds"
preloadSoundsFolder.Parent = SoundService

local warmedSoundsFolder = Instance.new("Configuration")
warmedSoundsFolder.Name = "WarmedSounds"
warmedSoundsFolder.Parent = SoundService

local unattachedSoundsFolder = Instance.new("Configuration")
unattachedSoundsFolder.Name = "UnattachedSounds"
unattachedSoundsFolder.Parent = SoundService

local soundGroupContainer = Instance.new("SoundGroup")
soundGroupContainer.Name = "SOUNDS"
soundGroupContainer.Volume = 1
soundGroupContainer.Parent = SoundService

local soundSchema: Types.SoundSchema = {
	PreloadedSounds = preloadSoundsFolder,
	WarmedSounds = warmedSoundsFolder,
	UnattachedSounds = unattachedSoundsFolder,

	SoundGroupContainer = soundGroupContainer,
	SoundGroups = {},

	SoundDefinitions = {},

	PreloadNames = {},
}

local preloadIdIndex: number = 0
local preloadIdHash: { [string]: boolean } = {}

------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------

--[[
	@param definitinon SoundDefinition -- The SoundDefinition to warm.

	Creates a Sound instance from a SoundDefinition and adds it to the warmed sounds cache.
]]
local function setPreloadGroup(groupFolder: Configuration)
	local preloadNames: { [number]: string } = soundSchema.PreloadNames

	local selector = ".VluxySF_Preload Sound, .VluxySF_Preload Folder, .VluxySF_Preload Configuration"
	local taggedInstances: { Instance } = groupFolder:QueryDescendants(selector)

	--fetch all preload sound instances
	local sounds: { Sound } = {}
	for _, instance in ipairs(taggedInstances) do
		if instance:IsA("Folder") or instance:IsA("Configuration") then
			local storedSounds = groupFolder:QueryDescendants("Sound")

			for _, sound in ipairs(storedSounds) do
				table.insert(sounds, sound)
			end
		else
			table.insert(sounds, instance :: Sound)
		end
	end

	--set to array
	for _, sound in ipairs(sounds) do
		local soundName: string = sound.Name

		if preloadIdHash[soundName] then
			continue
		end
		preloadIdHash[soundName] = true

		preloadIdIndex += 1

		preloadNames[preloadIdIndex] = soundName
	end
end

--[[
	@param groupFolder Configuration -- The Configuration folder representing the SoundGroup.
	@param soundGroup SoundGroup -- The SoundGroup instance to associate with the sounds in the group.

	Converts Sound instances within a SoundGroup folder to SoundDefinitions and associates them with the SoundGroup. Also handles preloading of sounds based on tags.
]]
local function setGroupedSoundsToDefinitions(groupFolder: Configuration, soundGroup: SoundGroup)
	local soundDefinitions: Types.SoundDefinitions = soundSchema.SoundDefinitions
	local preloadNames: { [number]: string } = soundSchema.PreloadNames
	local sounds: { Sound } = groupFolder:QueryDescendants("Sound")

	--sounds of group
	for _, sound in ipairs(sounds) do
		local soundName: string = sound.Name

		if soundDefinitions[soundName] then
			FormatMessage.Warn(`Duplicate sound with name "{soundName}" located at: {sound:GetFullName()}`)
			continue
		end

		soundDefinitions[soundName] = Converters.SoundToDefinition(sound, soundGroup)

		--preload ids
		if not sound:HasTag("VluxySF_Preload") then
			continue
		end

		if preloadIdHash[soundName] then
			continue
		end
		preloadIdHash[soundName] = true

		preloadIdIndex += 1

		preloadNames[preloadIdIndex] = soundName
	end

	return nil
end

------------------------------------------------------------------------------------------------------------------------

--[[
	@param soundsFolder Configuration -- The Configuration folder containing sound group folders and unattached sounds.

	Compiles sound data from the provided folder into the sound schema, converting Sound instances to SoundDefinitions and organizing them into groups. Also handles preloading of sounds based on tags.
]]
local function compile(soundsFolder: Configuration)
	local schemaSoundGroups: { [string]: SoundGroup } = soundSchema.SoundGroups
	local soundGroups: { Instance } = soundsFolder:GetChildren()

	for _, childFolder in ipairs(soundGroups) do
		if not childFolder:IsA("Configuration") then
			FormatMessage.Error(`The defined SoundGroup named {childFolder.Name} should be a Configuration Instance!`)

			continue
		end

		--new SoundGroup
		local soundGroup = Instance.new("SoundGroup")
		soundGroup.Name = childFolder.Name
		soundGroup.Volume = 1
		soundGroup.Parent = soundSchema.SoundGroupContainer

		schemaSoundGroups[childFolder.Name] = soundGroup

		--set sounds for the group
		setGroupedSoundsToDefinitions(childFolder, soundGroup)
		setPreloadGroup(childFolder)
	end
end

------------------------------------------------------------------------------------------------------------------------

--[[
	@param soundFolder Configuration -- The folder containing sound group folders and unattached sounds.

	Initializes the server sound system.
]]
local function initializeServerSoundSystem(soundsFolder: Configuration)
	compile(soundsFolder)

	soundsFolder:Destroy() --destroy folder after converting sounds to definitions to save memory

	--send conversion to client
	local soundRequestLimit = Ratelimit(5, 5)
	local dataLimitThunk = FormatMessage.WarnThunk("Sound data was requested too many times by a client!")

	soundRequest.Event = function(player: Player)
		if not soundRequestLimit(player) then
			dataLimitThunk()

			return nil
		end

		return soundSchema
	end
end

------------------------------------------------------------------------------------------------------------------------

--[[
	ServerSide of the sound system. Handles sound data storage and sending to clients.
]]
local ServerData = {}

--[[
	@param soundFolder Configuration -- The folder containing sound group folders and unattached sounds.
	@param strictNaming boolean -- Optional parameter to enforce strict naming of sounds within groups, default is true.

    Initializes the server sound system.
]]
function ServerData._initServer(soundFolder: Configuration | Folder)
	if not RunService:IsServer() then
		FormatMessage.Error(`This can only initialize on the server!`, 3)
	end
	if typeof(soundFolder) ~= "Instance" then
		FormatMessage.Error(`Invalid sound folder injected! {soundFolder:GetFullName()}`, 3)
	end

	initializeServerSoundSystem(soundFolder :: Configuration)
end

--[[
	@return Types.SoundSchema - The sound schema containing unattached sounds, sound groups, and sound definitions.

	Retrieves the SoundSchema.
]]
function ServerData.GetSoundSchema(): Types.SoundSchema
	return soundSchema
end

return ServerData
