--!strict

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

local HttpService = game:GetService("HttpService")

local Trove = require(src.Utility.Trove)

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

local pluginCleaner = Trove.new()

------------------------------------------------------------------------------------------------------------------------

--fixes issue were options widget doesnt open on first click.
optionsWidget.Enabled = true
task.delay(0.1, function()
	optionsWidget.Enabled = false
end)

------------------------------------------------------------------------------------------------------------------------
--STARTUP---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

Settings.SetPluginEnabled(false)
Settings.SetOptionsOpened(false)

--This finds the location of the sounds folder for websocket and auto baking to work.
AutoSearchLocation.Start(pluginCleaner)

--This is for direct requests from the extension.
SocketRequests.SetFullBake(FullBake.Now)

--This only for autoBaking.
AutoMonitorSounds.Init(pluginCleaner, function(folder)
	if not Settings.GetPluginEnabled() then
		return
	end

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
pluginCleaner:Connect(pluginEnableButton.Click, function()
	if os.time() - lastUserPluginEnablePress < 0.2 then
		return
	end
	lastUserPluginEnablePress = os.time()

	Settings.TogglePluginEnabled()
end)

--settings button
pluginCleaner:Connect(settingsButton.Click, function()
	Settings.ToggleOptionsOpened()
end)

------------------------------------------------------------------------------------------------------------------------
--CONNECTIONS-----------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--plugin enable
Toolbar.UpdatePluginEnableIcon()
if Settings.GetPluginEnabled() then
	SocketRequests.SetSocket(pluginCleaner, Settings.GetPort())
end

pluginCleaner:Connect(Settings.ListenPluginEnabled(), function(enabled: boolean)
	Toolbar.UpdatePluginEnableIcon()

	SocketRequests.TogglePort(pluginCleaner, enabled)
end)

--socket
pluginCleaner:Connect(SocketRequests.ListenSocketError(), function()
	Settings.SetPluginEnabled(false)
end)

------------------------------------------------------------------------------------------------------------------------

--options
pluginCleaner:Connect(optionsWidget:GetPropertyChangedSignal("Enabled"), function()
	Settings.SetOptionsOpened(optionsWidget.Enabled)
end)

pluginCleaner:Connect(Settings.ListenOptionsOpened(), function(opened: boolean)
	Toolbar.UpdateSettingsIcon()

	optionsWidget.Enabled = opened
end)

--port
pluginCleaner:Connect(Settings.ListenPortChanged(), function(_port: number)
	if not Settings.GetPluginEnabled() then
		return
	end

	SocketRequests.TogglePort(pluginCleaner, true)
end)

--cleanup
plugin.Unloading:Connect(function()
	Settings.SetPluginEnabled(false)
	Settings.SetOptionsOpened(false)

	pluginCleaner:Destroy()
end)

FormatMessage.Print("The plugin is now running!")
