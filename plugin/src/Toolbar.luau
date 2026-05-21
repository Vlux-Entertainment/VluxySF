--!strict

local ICONS = {
	ENABLED = "rbxassetid://115780670428316",
	DISABLED = "rbxassetid://104027421823400",
	SETTINGS_OPEN = "rbxassetid://128151593767682",
	SETTINGS_CLOSED = "rbxassetid://131160231402316",
}

local Settings = require(script.Parent.Tools.Settings)

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

local function getCurrentEnableIcon(): string
	return Settings.GetPluginEnabled() and ICONS.ENABLED or ICONS.DISABLED
end

local function getCurrentSettingsIcon(): string
	return Settings.GetOptionsOpened() and ICONS.SETTINGS_OPEN or ICONS.SETTINGS_CLOSED
end

--[[
	Topbar plugin Interface.
]]
local toolbar = plugin:CreateToolbar("Vluxy Sound Factory")

--plugin enable button
local pluginEnableText = "Vluxy Sound Factory"
local pluginEnableToolTip = "Enables sounds to be baked into lookup types!"
local pluginEnableButton = toolbar:CreateButton(pluginEnableText, pluginEnableToolTip, getCurrentEnableIcon())

--settings button
local settingsText = "Settings"
local settingsToolTip = "The available plugin settings for VLuxySF!"
local settingsButton = toolbar:CreateButton(settingsText, settingsToolTip, getCurrentSettingsIcon())

-- This module handles the plugin's toolbar buttons and their interactions.
local Toolbar = {}

--returns the current enable icon based on plugin state
function Toolbar.GetCurrentEnableIcon(): string
	return getCurrentEnableIcon()
end

--returns the current settings icon based on options panel state
function Toolbar.GetCurrentSettingsIcon(): string
	return getCurrentSettingsIcon()
end

function Toolbar.UpdatePluginEnableIcon()
	pluginEnableButton.Icon = getCurrentEnableIcon()
end

function Toolbar.UpdateSettingsIcon()
	settingsButton.Icon = getCurrentSettingsIcon()
end

--returns the plugin enable button so it can be manipulated by other modules
function Toolbar.GetPluginEnableButton(): PluginToolbarButton
	return pluginEnableButton
end

--returns the settings button so it can be manipulated by other modules
function Toolbar.GetSettingsButton(): PluginToolbarButton
	return settingsButton
end

return Toolbar
