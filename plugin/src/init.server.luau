--!strict

assert(plugin, "[VluxySF Plugin]: This code must run inside of a plugin")
if game:GetService("RunService"):IsRunning() then
	return
end

------------------------------------------------------------------------------------------------------------------------
--INIT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local src = script

local Settings = require(src.Tools.Settings)

local AutoSearchLocation = require(src.AutoSearchLocation)
local OptionsPanel = require(src.OptionsPanel)
local SocketRequests = require(src.SocketRequests)
local Toolbar = require(src.Toolbar)

local settingsButton = Toolbar.GetSettingsButton()
local pluginEnableButton = Toolbar.GetPluginEnableButton()

local optionsWidget = OptionsPanel.GetOptionsWidget()

--fixes issue were options widget doesnt open on first click.
optionsWidget.Enabled = true
task.delay(0.1, function()
	optionsWidget.Enabled = false
end)

------------------------------------------------------------------------------------------------------------------------
--STARTUP---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

AutoSearchLocation.Start()

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
