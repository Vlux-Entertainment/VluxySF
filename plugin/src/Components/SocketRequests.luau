--!strict

local HttpService = game:GetService("HttpService")

local src = script.Parent.Parent

local FormatMessage = require(src.Utility.FormatMessage)
local Trove = require(src.Utility.Trove)

local Settings = require(src.Tools.Settings)

local currentWebSocket: WebStreamClient?

local socketCleaner: Trove.Trove

local onSocketError = Instance.new("BindableEvent")

local fullBakeFunction: (Configuration?) -> { any } = nil

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
		socketCleaner:Destroy()
	end
end

--[[
	Fully Bakes the types and sends them to the Extension.
]]
function SocketRequests.SendFullBake(folder: Configuration?)
	if not fullBakeFunction then
		FormatMessage.Warn("Full bake function not set, cannot perform full bake!")
		return
	end
	if not currentWebSocket then
		FormatMessage.Warn("No active WebSocket connection, cannot send full bake!")
		return
	end

	currentWebSocket:Send(HttpService:JSONEncode(fullBakeFunction(folder)))
end

--[[
	@param port number -- the port number to connect the WebSocket to.

	Main socket for listening to the extension.
]]
function SocketRequests.SetSocket(port: number): Trove.Trove
	SocketRequests.CleanSocket()
	socketCleaner = Trove.new()

	local webSocket = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
		Url = "ws://127.0.0.1:" .. port,
		Method = "GET",
	})

	socketCleaner:Add(function()
		webSocket:Close()
	end)

	socketCleaner:Connect(webSocket.MessageReceived, function(message)
		--FormatMessage.Print(`Extension Request of {message} Recived!`)

		local recievedData = HttpService:JSONDecode(message)

		if recievedData.Name == "GetFullBake" then
			SocketRequests.SendFullBake()
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

	return socketCleaner
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
