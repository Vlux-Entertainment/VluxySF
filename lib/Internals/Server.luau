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

local unattachedSoundsFolder = Instance.new("Configuration")
unattachedSoundsFolder.Name = "UnattachedSounds"
unattachedSoundsFolder.Parent = SoundService

local soundGroupContainer = Instance.new("SoundGroup")
soundGroupContainer.Name = "SOUNDS"
soundGroupContainer.Volume = 1
soundGroupContainer.Parent = SoundService

local soundSchema: Types.SoundSchema = {
	UnattachedSounds = unattachedSoundsFolder,
	SoundGroupContainer = soundGroupContainer,

	SoundGroups = {},
	SoundDefinitions = {},

	PreloadIds = {},
}

local preloadIdIndex: number = 0
local preloadIdHash: { [string]: boolean } = {}

------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------

local function setGroupedSoundsToDefinitions(groupFolder: Configuration, soundGroup: SoundGroup)
	local soundDefinitions: Types.SoundDefinitions = soundSchema.SoundDefinitions
	local preloadIds: { [number]: string } = soundSchema.PreloadIds
	local sounds: { Sound } = groupFolder:QueryDescendants("Sound")

	--sounds of group
	for _, sound in ipairs(sounds) do
		local soundName: string = sound.Name
		local soundId: string = sound.SoundId

		if soundDefinitions[soundName] then
			FormatMessage.Warn(`Duplicate sound with name "{soundName}" located at: {sound:GetFullName()}`)
			return nil
		end

		soundDefinitions[soundName] = Converters.SoundToDefinition(sound, soundGroup)

		--preload ids
		if not sound:HasTag("VluxySF_Preload") then
			return nil
		end

		if preloadIdHash[soundId] then
			return nil
		end
		preloadIdHash[soundId] = true

		preloadIdIndex += 1

		preloadIds[preloadIdIndex] = soundId
	end

	return nil
end

------------------------------------------------------------------------------------------------------------------------

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
