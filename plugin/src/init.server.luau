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

local Sound = require(src.Utility.Sound)
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
pluginCleaner:Add(function()
	Settings.SetPluginEnabled(false)
	Settings.SetOptionsOpened(false)
end)

--This is for direct requests from the extension.
SocketRequests.SetFullBake(FullBake.Now)

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
--BOOT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local startCleaner: Trove.Trove = nil

--plugin enable
local function clearStart(playSound: boolean)
	if startCleaner then
		startCleaner:Destroy()
	end

	if playSound then
		Sound.PlayDisconnect()
	end

	Toolbar.UpdatePluginEnableIcon()
end

local function startPlugin()
	Sound.PlayConnect()
	Toolbar.UpdatePluginEnableIcon()

	clearStart(false)
	startCleaner = pluginCleaner:Extend()

	--get SOUNDS folder
	AutoSearchLocation.SetFolder()

	--network
	startCleaner:Add(SocketRequests.SetSocket(Settings.GetPort()))

	--auto baking
	startCleaner:Add(AutoMonitorSounds.NewMonitor(function(folder)
		if not Settings.GetPluginEnabled() then
			return
		end

		SocketRequests.SendFullBake(folder)
	end))
end

------------------------------------------------------------------------------------------------------------------------
--MAIN------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--enable/disable plugin
Toolbar.UpdatePluginEnableIcon()
if Settings.GetPluginEnabled() then
	startPlugin()
end

pluginCleaner:Connect(Settings.ListenPluginEnabled(), function(enabled: boolean)
	if enabled then
		startPlugin()
	else
		clearStart(true)
	end
end)

--socket error
pluginCleaner:Connect(SocketRequests.ListenSocketError(), function()
	Settings.SetPluginEnabled(false)
end)

------------------------------------------------------------------------------------------------------------------------
--SETTINGS--------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--options panel
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

	--restarts plugin if port has changed
	Settings.SetPluginEnabled(true)
end)

--diognostics
pluginCleaner:Connect(Settings.ListenDiagnosticsEnabled(), function(_enabled: number)
	if not Settings.GetPluginEnabled() then
		return
	end

	--restarts plugin if diognostics updated
	Settings.SetPluginEnabled(true)
end)

------------------------------------------------------------------------------------------------------------------------
--CLEANUP---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

plugin.Unloading:Connect(function()
	pluginCleaner:Destroy()
end)

FormatMessage.Print("The plugin is now running!")
