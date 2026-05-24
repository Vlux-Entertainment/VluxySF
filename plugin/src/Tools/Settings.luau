--!strict

local onPluginEnabled = Instance.new("BindableEvent")
local onPortChanged = Instance.new("BindableEvent")
local onSoundsLocationChanged = Instance.new("BindableEvent")
local onOptionsOpened = Instance.new("BindableEvent")
local onAutoBakeChanged = Instance.new("BindableEvent")
local onDiagnosticsEnabled = Instance.new("BindableEvent")

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

--[[
	A module for managing plugin settings and preferences, including plugin enable state, options panel state, socket settings, and sound file location.
]]
local Settings = {}

--[[
	Enable Plugin
]]

--checks plugin enable state
function Settings.GetPluginEnabled(): boolean
	if plugin:GetSetting("EnabledPlugin") == nil then
		plugin:SetSetting("EnabledPlugin", true)
	end

	if Settings.GetSoundsLocation() == nil then
		plugin:SetSetting("EnabledPlugin", false)
	end

	return plugin:GetSetting("EnabledPlugin")
end

--sets plugin enable state
function Settings.SetPluginEnabled(enabled: boolean)
	plugin:SetSetting("EnabledPlugin", enabled)

	onPluginEnabled:Fire(enabled)
end

--returns event that fires when plugin enable state changes, passing new state as argument
function Settings.ListenPluginEnabled(): RBXScriptSignal
	return onPluginEnabled.Event
end

--toggles plugin enable state and returns new state
function Settings.TogglePluginEnabled(): boolean
	local currentState = Settings.GetPluginEnabled()
	Settings.SetPluginEnabled(not currentState)

	return not currentState
end

--[[
	Options Toggle
]]

--checks options opened state
function Settings.GetOptionsOpened(): boolean
	if plugin:GetSetting("OptionsOpened") == nil then
		plugin:SetSetting("OptionsOpened", false)
	end

	return plugin:GetSetting("OptionsOpened")
end

--sets options opened state
function Settings.SetOptionsOpened(opened: boolean)
	plugin:SetSetting("OptionsOpened", opened)

	onOptionsOpened:Fire(opened)
end

--returns event that fires when options opened state changes, passing new state as argument
function Settings.ListenOptionsOpened(): RBXScriptSignal
	return onOptionsOpened.Event
end

--toggles options opened state and returns new state
function Settings.ToggleOptionsOpened(): boolean
	local currentState = Settings.GetOptionsOpened()
	Settings.SetOptionsOpened(not currentState)

	return not currentState
end

------------------------------------------------------------------------------------------------------------------------

--[[
	Socket
]]

--returns list of sound names for the full bake
function Settings.GetAutoBakeEnabled(): boolean
	if plugin:GetSetting("AutoBakeEnabled") == nil then
		plugin:SetSetting("AutoBakeEnabled", false)
	end

	return plugin:GetSetting("AutoBakeEnabled")
end

--sets auto bake enabled state
function Settings.SetAutoBake(enabled: boolean)
	plugin:SetSetting("AutoBakeEnabled", enabled)

	onAutoBakeChanged:Fire(enabled)
end

--returns list of sound names for the full bake
function Settings.ListenAutoBakeChanged(): RBXScriptSignal
	return onAutoBakeChanged.Event
end

------------------------------------------------------------------------------------------------------------------------

--[[
	Port
]]

--returns default port number
function Settings.GetDefaultPort(): number
	return 7842
end

--checks if the port is currently default
function Settings.IsDefaultPort(): boolean
	if Settings.GetPort() == nil then
		return true
	end

	return Settings.GetPort() == Settings.GetDefaultPort()
end

--checks port, if not set, sets to default (7842).
function Settings.GetPort(): number
	if plugin:GetSetting("Port") == nil then
		plugin:SetSetting("Port", Settings.GetDefaultPort())
	end

	return plugin:GetSetting("Port")
end

--sets port number
function Settings.SetPort(port: number)
	plugin:SetSetting("Port", port)

	onPortChanged:Fire(port)
end

--returns event that fires when port changes, passing new port as argument
function Settings.ListenPortChanged(): RBXScriptSignal
	return onPortChanged.Event
end

--[[
	Diagnostics Enabled
]]

--checks port, if not set, sets to default (7842).
function Settings.GetDiagnosticsEnabled(): boolean
	if plugin:GetSetting("DiagnosticsEnabled") == nil then
		plugin:SetSetting("DiagnosticsEnabled", false)
	end

	return plugin:GetSetting("DiagnosticsEnabled")
end

--sets port number
function Settings.SetDiagnosticsEnabled(enabled: boolean)
	plugin:SetSetting("DiagnosticsEnabled", enabled)

	onDiagnosticsEnabled:Fire(enabled)
end

function Settings.ToggleDiagnosticsEnabled(): boolean
	local currentState = Settings.GetDiagnosticsEnabled()
	Settings.SetDiagnosticsEnabled(not currentState)

	return not currentState
end

--returns event that fires when diagnostics enabled state changes, passing new state as argument
function Settings.ListenDiagnosticsEnabled(): RBXScriptSignal
	return onDiagnosticsEnabled.Event
end

--[[
	Sound Location
]]

--sound location
function Settings.GetSoundsLocation(): string?
	return plugin:GetSetting("FileLocation")
end

--sets sound location
function Settings.SetSoundsLocation(location: string)
	plugin:SetSetting("FileLocation", location)

	onSoundsLocationChanged:Fire(location)
end

--returns event that fires when sound location changes, passing new location as argument
function Settings.ListenSoundsLocationChanged(): RBXScriptSignal
	return onSoundsLocationChanged.Event
end

return Settings
