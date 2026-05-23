--!strict

------------------------------------------------------------------------------------------------------------------------

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local library = script.Parent.Parent

local FormatMessage = require(library.Utility.FormatMessage)
local RemoteFunction = require(library.Utility.RemoteFunction)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------------------

local soundSchema: Types.SoundSchema

----------------------------------------------------------------------------------------------------------------

--[[
	Requests SoundSchema from server.

	@yields

	@return Types.SoundSchema -- The sound schema containing unattached sounds, sound groups, and sound definitions.
]]
local function getDataForClient(): Types.SoundSchema
	local remoteFunction = RemoteFunction.new("SoundRequest")
	local response = remoteFunction:Fire()

	if response then
		return response
	else
		FormatMessage.Warn("Server did not return sounds to local player, re-attempting!")

		task.wait(0.5)

		return getDataForClient()
	end
end

--[[
	Extracts preload sound ids from the schema and preloads them.

	@param timeout number? -- Optional timeout for preloading sounds, default is 5 seconds.
]]
local function setPreloadSounds(timeout: number?)
	if #soundSchema.PreloadIds == 0 then
		return
	end

	local preloadSounds = {}
	local realTimeout = timeout or 5

	local complete = Instance.new("BindableEvent")
	complete.Name = "PreloadComplete"
	complete.Parent = script

	--we add the ids to sound instances because preload fails will raw id for some reason.
	for _, soundId in ipairs(soundSchema.PreloadIds) do
		local newSound = Instance.new("Sound")
		newSound.SoundId = soundId
		newSound.Name = "PreloadSound"
		newSound.Parent = script

		table.insert(preloadSounds, newSound)
	end

	local callback = function(assetId: string, assetFetchStatus: Enum.AssetFetchStatus)
		if assetFetchStatus == Enum.AssetFetchStatus.Success then
			return
		end

		FormatMessage.Warn(`Failed to preload sound with assetId {assetId}, status: {assetFetchStatus}`)
	end

	task.spawn(function()
		local t = os.clock()

		ContentProvider:PreloadAsync(preloadSounds, callback)

		FormatMessage.Print(`Preloaded {#preloadSounds} sounds in {os.clock() - t} seconds!`)

		if not complete then
			return
		end

		complete:Fire()
	end)

	task.delay(realTimeout, function()
		if not complete then
			return
		end

		FormatMessage.Warn("Preloading sounds timed out! Continuing with compile process!")

		complete:Fire()
	end)

	complete.Event:Wait()
	complete:Destroy()
	complete = nil :: any

	--we only needed the instances to preload.
	for _, sound in ipairs(preloadSounds) do
		sound:Destroy()
	end
end

------------------------------------------------------------------------------------------------------------------------

--[[
	ClientSide of the sound system. Handles sound data storage and retrieval for the client.
]]
local ClientData = {}

--[[
    Initializes the client sound system.

	@yields

	@param timeout number? -- Optional timeout for preloading sounds, default is 5 seconds.
]]
function ClientData._initClient(timeout: number?)
	if RunService:IsServer() then
		FormatMessage.Error("Cannot initialize client on server!")
	end

	soundSchema = getDataForClient()

	setPreloadSounds(timeout)
end

--[[
	Retrieves the SoundSchema.

	@return Types.SoundSchema -- The sound schema containing unattached sounds, sound groups, and sound definitions.
]]
function ClientData.GetSoundSchema(): Types.SoundSchema
	return soundSchema
end

return ClientData
