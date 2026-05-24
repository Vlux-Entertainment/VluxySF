--!strict

local src = script.Parent.Parent

local Settings = require(src.Tools.Settings)

local EnableOption = require(src.RawUI.EnableOption)
local SettingsUI = require(src.RawUI.SettingsUI)
local TextBoxOption = require(src.RawUI.TextBoxOption)

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

------------------------------------------------------------------------------------------------------------------------

local optionsDockWidgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 300, 400, 300, 400)
local optionsWidget = plugin:CreateDockWidgetPluginGuiAsync("OptionsPanel", optionsDockWidgetInfo)

------------------------------------------------------------------------------------------------------------------------

local optionsPanel = SettingsUI.New(optionsWidget)

--port option
local startingPortValue = Settings.IsDefaultPort() and "" or tostring(Settings.GetPort())
local portOption, portInput = TextBoxOption.New(1, "Port", startingPortValue, "Default: " .. Settings.GetDefaultPort())
portOption.Parent = optionsPanel

TextBoxOption.ForceOnlyNumbers(portInput)

local previousPortValue = portInput.Text
portInput.FocusLost:Connect(function()
	if portInput.Text == previousPortValue then
		return
	end
	previousPortValue = portInput.Text

	--from here it should only run when new information is added.

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

------------------------------------------------------------------------------------------------------------------------

--diognostics option
local diagnosticsOption, diagnosticsButton, diagnosticsSetState, diagnosticsGetState =
	EnableOption.New(2, "Diagnostics", Settings.GetDiagnosticsEnabled())
diagnosticsOption.Parent = optionsPanel

diagnosticsButton.MouseButton1Down:Connect(function()
	Settings.ToggleDiagnosticsEnabled()

	diagnosticsSetState(Settings.GetDiagnosticsEnabled())
end)

------------------------------------------------------------------------------------------------------------------------

--[[
	A module for managing the options panel of the plugin. It provides functions to get the options widget and the individual options for the settings UI.
]]
local OptionsPanel = {}

--[[
	@return DockWidgetPluginGui -- The widget that contains the settings UI.

	Returns the options widget that contains the settings UI. You can parent your settings options to this widget.
]]
function OptionsPanel.GetOptionsWidget(): DockWidgetPluginGui
	return optionsWidget
end
--[[
	@return Frame -- The frame that contains the port option.
	@return TextBox -- The TextBox for the port option.

	Returns the port option of the Settings UI.
]]
function OptionsPanel.GetPortOption(): (Frame, TextBox)
	return portOption, portInput
end

--[[
	@return Frame -- The frame that contains the diagnostics option.
	@return TextButton -- The button that toggles the diagnostics option.
	@return () -> boolean -- A function that returns the current state of the diagnostics option.

	Returns the diagnostics options of the Settings UI.
]]
function OptionsPanel.GetDiagnosticsOption(): (Frame, TextButton, (boolean) -> (), () -> boolean)
	return diagnosticsOption, diagnosticsButton, diagnosticsSetState, diagnosticsGetState
end

return OptionsPanel
