--!strict

local ICONS = {
	ENABLED = "rbxassetid://115780670428316",
	DISABLED = "rbxassetid://104027421823400",
	SETTINGS_OPEN = "rbxassetid://128151593767682",
	SETTINGS_CLOSED = "rbxassetid://131160231402316",
}

------------------------------------------------------------------------------------------------------------------------

local src = script.Parent.Parent

local Settings = require(src.Tools.Settings)

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

------------------------------------------------------------------------------------------------------------------------

local function getCurrentEnableIcon(): string
	return Settings.GetPluginEnabled() and ICONS.ENABLED or ICONS.DISABLED
end

local function getCurrentSettingsIcon(): string
	return Settings.GetOptionsOpened() and ICONS.SETTINGS_OPEN or ICONS.SETTINGS_CLOSED
end

------------------------------------------------------------------------------------------------------------------------
-- Create the toolbar and buttons

local toolbar = plugin:CreateToolbar("Vluxy Sound Factory")

--plugin enable button
local pluginEnableText = "Vluxy Sound Factory"
local pluginEnableToolTip = "Enables sounds to be baked into lookup types!"
local pluginEnableButton = toolbar:CreateButton(pluginEnableText, pluginEnableToolTip, getCurrentEnableIcon())

--settings button
local settingsText = "Settings"
local settingsToolTip = "The available plugin settings for VLuxySF!"
local settingsButton = toolbar:CreateButton(settingsText, settingsToolTip, getCurrentSettingsIcon())

------------------------------------------------------------------------------------------------------------------------

--[[
	A module for managing the plugin's toolbar, including the plugin enable button and settings button.
]]
local Toolbar = {}

--[[
	@return string -- The current plugin enable icon based on plugin enabled state.

	Returns the current plugin enable icon based on plugin enabled state.
]]
function Toolbar.GetCurrentEnableIcon(): string
	return getCurrentEnableIcon()
end

--[[
	@return string -- The current settings icon based on options opened state.

	Returns the current settings icon based on options opened state.
]]
function Toolbar.GetCurrentSettingsIcon(): string
	return getCurrentSettingsIcon()
end

--[[
	Updates the plugin enable button icon based on the current plugin enabled state.
]]
function Toolbar.UpdatePluginEnableIcon()
	pluginEnableButton.Icon = getCurrentEnableIcon()
end

--[[
	Updates the settings button icon based on the current options opened state.
]]
function Toolbar.UpdateSettingsIcon()
	settingsButton.Icon = getCurrentSettingsIcon()
end

--[[
	@return PluginToolbarButton -- The plugin enable button.

	Returns the plugin enable button so it can be manipulated by other modules.
]]
function Toolbar.GetPluginEnableButton(): PluginToolbarButton
	return pluginEnableButton
end

--[[
	@return PluginToolbarButton -- The settings button.

	Returns the settings button so it can be manipulated by other modules.
]]
function Toolbar.GetSettingsButton(): PluginToolbarButton
	return settingsButton
end

return Toolbar
