--!strict
--!native

------------------------------------------------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local library = script.Parent.Parent

local FormatMessage = require(library.Utility.FormatMessage)
local Ratelimit = require(library.Utility.RateLimit)
local RemoteFunction = require(library.Utility.RemoteFunction)

local Converters = require(library.Tools.Converters)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------------------

local unattachedSoundsFolder = Instance.new("Configuration")
unattachedSoundsFolder.Name = "UnattachedSounds"
unattachedSoundsFolder.Parent = SoundService

local soundGroupContainerFolder = Instance.new("Configuration")
soundGroupContainerFolder.Name = "SoundGroups"
soundGroupContainerFolder.Parent = SoundService

local soundSchema: Types.SoundSchema = {
	UnattachedSounds = unattachedSoundsFolder,
	SoundGroupContainer = soundGroupContainerFolder,

	SoundGroups = {},
	SoundDefinitions = {},

	PreloadIds = {},
}

------------------------------------------------------------------------------------------------------------------------

--[[
    Sets grouped sounds from a folder into the sound definitions.

    @param soundDefinitions SoundDefinitions -- The sound definitions dictionary to add the sounds to.
    @param childFolder Instance -- The folder containing the sounds to add.
]]
local function setGroupedSounds(soundDefinitions: Types.SoundDefinitions, childFolder: Instance)
	local sounds = childFolder:QueryDescendants("Sound")

	for _, sound in ipairs(sounds) do
		if soundDefinitions[sound.Name] then
			FormatMessage.Error(`Duplicate sound with name "{sound.Name}" located at: {sound:GetFullName()}`)
		end

		local success, result = pcall(function()
			local newDefinition = Converters.SoundToDefinition(sound)
			newDefinition.Properties.SoundGroup = childFolder.Name --add to sound group

			return newDefinition
		end)

		if success then
			soundDefinitions[sound.Name] = result
		else
			FormatMessage.Warn(result)
		end
	end
end

--[[
    Creates sound definitions for all sounds in the given folder and organizes them by group.

    @param soundFolder Configuration -- The folder containing sound group folders and unattached sounds.

    @return SoundDefinitions -- The created sound definitions dictionary.
]]
local function createSoundDefinitions(soundFolder: Configuration): Types.SoundDefinitions
	local soundDefinitions: Types.SoundDefinitions = {}

	for _, childFolder in pairs(soundFolder:GetChildren()) do
		setGroupedSounds(soundDefinitions, childFolder)
	end

	return soundDefinitions
end

--[[
	Converts a SoundConfig to a list of SoundGroups.

	@param soundConfig Configuration -- The SoundConfig to convert.
	@param parent Instance -- The parent instance to create the SoundGroups under.

	@return SoundGroups -- A table of SoundGroups created from the SoundConfig.
]]
function soundConfigToSoundGroups(soundConfig: Configuration, parent: Instance): Types.SoundGroups
	local soundGroups: Types.SoundGroups = {}

	--first set of children defines sound groups
	for _, childFolder in pairs(soundConfig:GetChildren()) do
		if not childFolder:IsA("Configuration") then
			FormatMessage.Error(`The defined SoundGroup named {childFolder.Name} should be a Configuration Instance!`)

			continue
		end

		local soundGroup = Instance.new("SoundGroup")
		soundGroup.Name = childFolder.Name
		soundGroup.Parent = parent

		soundGroups[childFolder.Name] = soundGroup
	end

	return soundGroups
end

--[[
	Converts a SoundConfig to a list of SoundIds that should be preloaded.

	@param soundConfig Configuration -- The SoundConfig to convert.

	@return { string } -- A list of SoundIds to preload.
]]
function soundConfigToPreloadIds(soundConfig: Configuration): { string }
	local preloadIds = {}

	local function getIdsFromParent(folder: Instance)
		local sounds = folder:QueryDescendants("Sound")

		for _, sound in ipairs(sounds) do
			table.insert(preloadIds, sound.SoundId)
		end
	end

	local preloadFolders = CollectionService:GetTagged("_VluxySF_Preload")
	for _, folder in ipairs(preloadFolders) do
		if not folder:IsDescendantOf(soundConfig) then
			FormatMessage.Warn(`Preload was tagged outside of the SOUNDS folder! : {folder:GetFullName()}`)
			continue
		end

		if not folder:IsA("Folder") and not folder:IsA("Configuration") and not folder:IsA("Sound") then
			FormatMessage.Warn(`Preload was tagged on an invalid Instance Class! : {folder:GetFullName()}`)
			continue
		end

		if folder:IsA("Sound") then
			table.insert(preloadIds, folder.SoundId)
		else
			getIdsFromParent(folder)
		end
	end

	return preloadIds
end

------------------------------------------------------------------------------------------------------------------------

--[[
	Initializes the server sound system.

	Creates unattached sound folder and converts all sounds into sound definitions organized by group, then sets up a RemoteFunction for clients to request the sound schema.

	@param soundFolder Configuration -- The folder containing sound group folders and unattached sounds.
]]
local function initializeServerSoundSystem(soundFolder: Configuration)
	--set groups
	soundSchema.SoundGroups = soundConfigToSoundGroups(soundFolder, soundSchema.SoundGroupContainer)

	--convert Sounds
	soundSchema.SoundDefinitions = createSoundDefinitions(soundFolder)

	--set preload
	soundSchema.PreloadIds = soundConfigToPreloadIds(soundFolder)

	soundFolder:Destroy() --destroy folder after converting sounds to definitions to save memory

	--send conversion to client
	local soundRequestLimit = Ratelimit(5, 5)
	local dataLimitThunk = FormatMessage.WarnThunk("Sound data was requested too many times by a client!")

	RemoteFunction.new("SoundRequest", function(player: Player)
		if not soundRequestLimit(player) then
			dataLimitThunk()

			return nil
		end

		return soundSchema
	end)
end

------------------------------------------------------------------------------------------------------------------------

--[[
	ServerSide of the sound system. Handles sound data storage and sending to clients.
]]
local ServerData = {}

--[[
    Initializes the server sound system.

	soundFolder should be on the server side.
	
	@param soundFolder Configuration -- The folder containing sound group folders and unattached sounds.
	@param strictNaming boolean -- Optional parameter to enforce strict naming of sounds within groups, default is true. If true, duplicate sound names within the same group will trigger a warning.
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
	Retrieves the SoundSchema.

	@return Types.SoundSchema - The sound schema containing unattached sounds, sound groups, and sound definitions.
]]
function ServerData.GetSoundSchema(): Types.SoundSchema
	return soundSchema
end

return ServerData
