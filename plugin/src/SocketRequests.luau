--!strict
local HttpService = game:GetService("HttpService")

local FormatMessage = require(script.Parent.Utility.FormatMessage)
local Sound = require(script.Parent.Utility.Sound)
local Trove = require(script.Parent.Utility.Trove)

local Settings = require(script.Parent.Tools.Settings)
local SoundsLocation = require(script.Parent.Tools.SoundsLocation)

local currentWebSocket: WebStreamClient?

local socketCleaner: Trove.Trove
local autoBakeCleaner: Trove.Trove

local onSocketError = Instance.new("BindableEvent")

-- This module handles all the requested data from the port.
local SocketRequests = {}

--cleaner for auto bake
function SocketRequests.ClearAutoBakeCleaner()
	if autoBakeCleaner then
		autoBakeCleaner:Clean()
	end
end

--auto bake that connects to the folder to update
function SocketRequests._monitorAutoBake()
	SocketRequests.ClearAutoBakeCleaner()
	autoBakeCleaner = Trove.new()

	local formatedLocation = Settings.GetSoundsLocation()
	if not formatedLocation then
		return
	end

	local folderInstance = SoundsLocation.GetSoundsFolderFromLocation(formatedLocation)
	if not folderInstance then
		return
	end

	local function bakeAndSend()
		if not Settings.GetAutoBakeEnabled() then
			return
		end

		local result = SocketRequests.FullBake(folderInstance)

		if currentWebSocket then
			currentWebSocket:Send(HttpService:JSONEncode(result))
		else
			FormatMessage.Warn("No active WebSocket connection to send auto bake results!")
		end
	end

	bakeAndSend()
	autoBakeCleaner:Connect(folderInstance.DescendantAdded, function(descendant: Instance)
		if not descendant:IsA("Sound") then
			return
		end

		bakeAndSend()
	end)

	autoBakeCleaner:Connect(folderInstance.DescendantRemoving, function(_descendant: Instance)
		bakeAndSend()
	end)
end

--adjusts folder location if changed for auto bake
function SocketRequests.AutoBakeInit()
	SocketRequests._monitorAutoBake()

	Settings.ListenSoundsLocationChanged():Connect(function(_location: string)
		SocketRequests._monitorAutoBake()
	end)
end

------------------------------------------------------------------------------------------------------------------------

--this finds all the sound names in the soundsFolder
function SocketRequests.FullBake(folder: Configuration?): { string }
	local soundNames = {}

	local soundsFolder: Configuration? = folder

	if not folder then
		local formatedLocation = Settings.GetSoundsLocation()
		if not formatedLocation then
			FormatMessage.Error("Could not fetch sounds folder location for full bake!")
			return {}
		end

		soundsFolder = SoundsLocation.GetSoundsFolderFromLocation(formatedLocation :: string)
	end

	if not soundsFolder then
		FormatMessage.Error("Could not find sounds folder at the provided location for full bake!")
		return {}
	end

	--if folder is provided it starts to do stuff here
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

	return { Name = "FullBakeResult", SoundNames = soundNames }
end

------------------------------------------------------------------------------------------------------------------------

--this is used to clean up the websocket connection when the plugin is disabled or the port changes
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

		local recievedData = HttpService:JSONDecode(message)

		if recievedData.Name == "GetFullBake" then
			local result = SocketRequests.FullBake()

			webSocket:Send(HttpService:JSONEncode(result))
		elseif recievedData.Name == "SetExtensionSettings" then --this doesnt work atm
			Settings.SetAutoBake(recievedData.AutoBake)
		else
			FormatMessage.Warn(`Received unknown message: {message}`)
		end
	end)

	socketCleaner:Connect(webSocket.Error, function(err)
		onSocketError:Fire()

		FormatMessage.Warn("WebSocket connection error: " .. err)
	end)

	currentWebSocket = webSocket
end

------------------------------------------------------------------------------------------------------------------------

--returns event that fires when there is a socket error, such as the connection being closed or failing to connect
function SocketRequests.ListenSocketError(): RBXScriptSignal
	return onSocketError.Event
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
