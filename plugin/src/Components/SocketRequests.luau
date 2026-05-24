--!strict

local HttpService = game:GetService("HttpService")

local src = script.Parent.Parent

local FormatMessage = require(src.Utility.FormatMessage)
local Sound = require(src.Utility.Sound)
local Trove = require(src.Utility.Trove)

local Settings = require(src.Tools.Settings)

local currentWebSocket: WebStreamClient?

local socketCleaner: Trove.Trove

local onSocketError = Instance.new("BindableEvent")

local fullBakeFunction: () -> { any } = nil

--[[
	this module handles the WebSocket connection between the plugin and the extension, allowing for real-time communication and updates between the two.
]]
local SocketRequests = {}

------------------------------------------------------------------------------------------------------------------------
--CORE------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	returns event that fires when the auto bake setting is changed, passing the new auto bake value as an argument.
]]
function SocketRequests.CleanSocket()
	if socketCleaner then
		socketCleaner:Clean()
	end
end

--[[
	@param port number -- the port number to connect the WebSocket to.

	this initializes the auto bake functionality, which listens for changes in the sounds folder and sends updates to the client when changes are made if auto bake is enabled.
]]
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
			if not fullBakeFunction then
				FormatMessage.Warn("Full bake function not set, cannot perform full bake!")
				return
			end

			webSocket:Send(HttpService:JSONEncode(fullBakeFunction()))
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

--[[
	@param enabled boolean -- whether the port should be enabled or not, which is determined by whether the plugin is enabled or not.

	This toggles the port connection on or off depending on the enabled parameter.
]]
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

------------------------------------------------------------------------------------------------------------------------
--COMMON----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	@return WebSocketClient? -- the current WebSocket connection, or nil if there is no active connection.

	Returns the current WebSocket connection, or nil if there is no active connection.
]]
function SocketRequests.GetSocket(): WebStreamClient?
	return currentWebSocket
end

--[[
	@param fullBake () -> { any } -- the function that will be called when the client requests a full bake.

	This sets the function that will be called when the client requests a full bake.
]]
function SocketRequests.SetFullBake(fullBake: () -> { any })
	fullBakeFunction = fullBake
end

--[[
	@return RBXScriptSignal -- socket error signal

	Returns event that fires when there is a socket error, such as the extension trying to connect to the plugin when it is not enabled.
]]
function SocketRequests.ListenSocketError(): RBXScriptSignal
	return onSocketError.Event
end

return SocketRequests
