--!strict
--!optimize 2

------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local library = script.Parent.Parent

local Converters = require(ReplicatedStorage.VluxySF.Tools.Converters)
local FormatMessage = require(library.Utility.FormatMessage)
local RemoteFunction = require(library.Utility.RemoteFunction)

local Preloading = require(library.Tools.Preloading)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------------------

local soundRequest = RemoteFunction.new("SoundRequest")

local soundSchema: Types.SoundSchema

----------------------------------------------------------------------------------------------------------------

--[[
	@yields

	@return Types.SoundSchema -- The sound schema containing unattached sounds, sound groups, and sound definitions.

	Requests SoundSchema from server.
]]
local function getDataForClient()
	local response = soundRequest:Fire()

	if response then
		soundSchema = response
	else
		FormatMessage.Warn("Server did not return sounds to local player, re-attempting!")

		task.wait(0.5)

		getDataForClient()
	end
end

--[[
	@yields

	@param timeout number? -- Optional timeout for preloading sounds, default is 5 seconds.

	Extracts preload sound names from the schema and preloads them.
]]
local function setPreloadSounds(timeout: number?)
	local realTimeout = timeout or 5

	local complete = Instance.new("BindableEvent")
	complete.Name = "PreloadComplete"
	complete.Parent = script

	local preloadThread = task.spawn(function()
		local preloadSounds: { Sound } = {}

		for _, preloadName in ipairs(soundSchema.PreloadNames) do
			local soundDefinition = soundSchema.SoundDefinitions[preloadName]
			local sound = Converters.DefinitionToSound(soundDefinition)

			table.insert(preloadSounds, sound)
		end

		Preloading.Selected(soundSchema.PreloadedSounds, table.unpack(preloadSounds))

		if not complete then
			return
		end

		complete:Fire()
	end)

	local timeoutThread = task.delay(realTimeout, function()
		if not complete then
			return
		end

		FormatMessage.Warn("Preloading sounds timed out! Continuing with compile process!")

		complete:Fire()
	end)

	complete.Event:Wait()

	--cleanup
	if preloadThread then
		task.cancel(preloadThread)
	end
	if timeoutThread then
		task.cancel(timeoutThread)
	end

	complete:Destroy()
	complete = nil :: any
end

------------------------------------------------------------------------------------------------------------------------

--[[
	ClientSide of the sound system. Handles sound data storage and retrieval for the client.
]]
local ClientData = {}

--[[
	@yields

	@param timeout number? -- Optional timeout for preloading sounds, default is 5 seconds.

	Initializes the client sound system.
]]
function ClientData._initClient(timeout: number?)
	if RunService:IsServer() then
		FormatMessage.Error("Cannot initialize client on server!")
	end

	getDataForClient()

	setPreloadSounds(timeout)
end

--[[
	@return Types.SoundSchema -- The sound schema containing unattached sounds, sound groups, and sound definitions.

	Retrieves the SoundSchema.
]]
function ClientData.GetSoundSchema(): Types.SoundSchema
	return soundSchema
end

return ClientData
