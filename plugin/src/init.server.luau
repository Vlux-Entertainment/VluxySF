--!strict

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local src = script

local FormatMessage = require(src.Utility.FormatMessage)

------------------------------------------------------------------------------------------------------------------------
--INIT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

assert(plugin, FormatMessage.NewMessage("This code must run inside of a plugin!"))
if RunService:IsRunning() then
	return
end

------------------------------------------------------------------------------------------------------------------------

local Settings = require(src.Tools.Settings)

local AutoMonitorSounds = require(src.Components.AutoMonitorSounds)
local AutoSearchLocation = require(src.Components.AutoSearchLocation)
local FullBake = require(src.Components.FullBake)
local SocketRequests = require(src.Components.SocketRequests)

local OptionsPanel = require(src.UI.OptionsPanel)
local Toolbar = require(src.UI.Toolbar)

------------------------------------------------------------------------------------------------------------------------

local settingsButton = Toolbar.GetSettingsButton()
local pluginEnableButton = Toolbar.GetPluginEnableButton()

local optionsWidget = OptionsPanel.GetOptionsWidget()

local currentWebSocket: WebStreamClient? = nil

------------------------------------------------------------------------------------------------------------------------

--fixes issue were options widget doesnt open on first click.
optionsWidget.Enabled = true
task.delay(0.1, function()
	optionsWidget.Enabled = false
end)

------------------------------------------------------------------------------------------------------------------------
--STARTUP---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--This finds the location of the sounds folder for websocket and auto baking to work.
AutoSearchLocation.Start()

--This is for direct requests from the extension.
SocketRequests.SetFullBake(FullBake.Now)

--This only for autoBaking.
AutoMonitorSounds.Init(function(folder)
	local result = FullBake.Now(folder)

	if currentWebSocket then
		currentWebSocket:Send(HttpService:JSONEncode(result))
	else
		FormatMessage.Warn("No active WebSocket connection to send auto bake results!")
	end
end)

------------------------------------------------------------------------------------------------------------------------
--TOOLBAR_BUTTONS-------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local lastUserPluginEnablePress = 0
pluginEnableButton.Click:Connect(function()
	if os.time() - lastUserPluginEnablePress < 0.2 then
		return
	end
	lastUserPluginEnablePress = os.time()

	Settings.TogglePluginEnabled()
end)

--settings button
settingsButton.Click:Connect(function()
	Settings.ToggleOptionsOpened()
end)

------------------------------------------------------------------------------------------------------------------------
--CONNECTIONS-----------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--plugin enable
if Settings.GetPluginEnabled() then
	SocketRequests.SetSocket(Settings.GetPort())
end

Settings.ListenPluginEnabled():Connect(function(enabled: boolean)
	Toolbar.UpdatePluginEnableIcon()

	SocketRequests.TogglePort(enabled)
end)

--socket
SocketRequests.ListenSocketError():Connect(function()
	Settings.SetPluginEnabled(false)
end)

--port
Settings.ListenPortChanged():Connect(function(_port: number)
	if not Settings.GetPluginEnabled() then
		return
	end

	SocketRequests.TogglePort(true)
end)

--options
optionsWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	Settings.SetOptionsOpened(optionsWidget.Enabled)
end)

Settings.ListenOptionsOpened():Connect(function(opened: boolean)
	Toolbar.UpdateSettingsIcon()

	optionsWidget.Enabled = opened
end)

------------------------------------------------------------------------------------------------------------------------
--OPTIONS---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local _, portInput = OptionsPanel.GetPortOption()
portInput.FocusLost:Connect(function(_enterPressed: boolean)
	if portInput.Text == "" then
		Settings.SetPort(Settings.GetDefaultPort())
		return
	end

	local portNumber = tonumber(portInput.Text)
	if not portNumber then
		Settings.SetPort(Settings.GetDefaultPort())

		portInput.Text = ""
		return
	end

	Settings.SetPort(portNumber)
end)
