--!strict
local HttpService = game:GetService("HttpService")

local FormatMessage = require(script.Parent.Utility.FormatMessage)
local Settings = require(script.Parent.Tools.Settings)
local Sound = require(script.Parent.Utility.Sound)
local SoundsLocation = require(script.Parent.Tools.SoundsLocation)
local Trove = require(script.Parent.Utility.Trove)

local onSocketError = Instance.new("BindableEvent")

-- This module handles all the requested data from the port.
local SocketRequests = {}

--this finds all the sound names in the soundsFolder
function SocketRequests.FullBake(): { string }
	local soundNames = {}

	local formatedLocation = Settings.GetSoundsLocation()
	if not formatedLocation then
		FormatMessage.Error("Could not fetch sounds folder location for full bake!")
		return {}
	end

	local soundsFolder = SoundsLocation.GetSoundsFolderFromLocation(formatedLocation :: string)
	if not soundsFolder then
		FormatMessage.Error("Could not find sounds folder at the provided location for full bake!")
		return {}
	end

	local sounds = soundsFolder:QueryDescendants("Sound")
	if #sounds == 0 then
		FormatMessage.Warn("No sounds found in the specified sounds folder for full bake!")
		return {}
	end

	for _, sound in sounds do
		if table.find(soundNames, sound.Name) then
			continue
		end

		table.insert(soundNames, sound.Name)
	end

	return soundNames
end

--this is supposed to find all the sound names in the soundsFolder that are not already in the plugin's settings.
function SocketRequests.MinimalBake()
	FormatMessage.Warn("Minimal bake is not implemented yet!")
	return {}
end

--returns event that fires when there is a socket error, such as the connection being closed or failing to connect
function SocketRequests.ListenSocketError(): RBXScriptSignal
	return onSocketError.Event
end

--this is used to clean up the websocket connection when the plugin is disabled or the port changes
local socketCleaner: Trove.Trove
function SocketRequests.CleanSocket()
	if socketCleaner then
		socketCleaner:Clean()
	end
end

--this sets up the websocket connection and listens for messages
function SocketRequests.SetSocket(port: number)
	SocketRequests.CleanSocket()
	socketCleaner = Trove.new()

	local webSocket = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
		Url = "ws://127.0.0.1:" .. port,
		Method = "GET",
	})

	socketCleaner:Connect(webSocket.MessageReceived, function(message)
		FormatMessage.Print(`Extension Request of {message} Recived!`)

		if message == "GetFullBake" then
			local result = SocketRequests.FullBake()
			local data = { Name = "FullBakeResult", SoundNames = result }

			webSocket:Send(HttpService:JSONEncode(data))
		elseif message == "GetMinimalBake" then --this doesnt work atm
			local result = SocketRequests.MinimalBake()
			local data = { Name = "MinimalBakeResult", NewSoundNames = result, RemovedSoundNames = {} }

			webSocket:Send(HttpService:JSONEncode(data))
		else
			FormatMessage.Warn(`Received unknown message: {message}`)
		end
	end)

	socketCleaner:Connect(webSocket.Error, function(err)
		onSocketError:Fire()

		FormatMessage.Warn("WebSocket connection error: " .. err)

		if err ~= 400 then
			return
		end

		FormatMessage.Warn("Make sure your ports match!")
	end)
end

--toggles the port if a location exists and plays sounds
function SocketRequests.TogglePort(enabled: boolean)
	if Settings.GetSoundsLocation() == nil then
		SocketRequests.CleanSocket()

		FormatMessage.Warn("Could not locate a Configuration named SOUNDS!")
		return
	end

	if enabled then
		SocketRequests.SetSocket(Settings.GetPort())

		Sound.PlayConnect()
	else
		SocketRequests.CleanSocket()

		Sound.PlayDisconnect()
	end
end

return SocketRequests
