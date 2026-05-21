--!strict
local ServerStorage = game:GetService("ServerStorage")

local Settings = require(ServerStorage.VluxySFPlugin.Tools.Settings)

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

local optionsDockWidgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 300, 400, 300, 400)
local optionsWidget = plugin:CreateDockWidgetPluginGuiAsync("OptionsPanel", optionsDockWidgetInfo)

-- This module handles the options panel UI and its interactions.

local widget = optionsWidget

local uIListLayout = Instance.new("UIListLayout")
uIListLayout.Name = "UIListLayout"
uIListLayout.Padding = UDim.new(0, 8)
uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout.Parent = widget

local uISizeConstraint = Instance.new("UISizeConstraint")
uISizeConstraint.Name = "UISizeConstraint"
uISizeConstraint.MinSize = Vector2.new(300, 400)
uISizeConstraint.Parent = widget

local uIPadding = Instance.new("UIPadding")
uIPadding.Name = "UIPadding"
uIPadding.PaddingBottom = UDim.new(0, 8)
uIPadding.PaddingLeft = UDim.new(0, 8)
uIPadding.PaddingRight = UDim.new(0, 8)
uIPadding.PaddingTop = UDim.new(0, 8)
uIPadding.Parent = widget

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.LayoutOrder = 1
header.Size = UDim2.new(1, 0, 0, 26)

local name = Instance.new("TextLabel")
name.Name = "Name"
name.Active = true
name.BackgroundTransparency = 1
name.ClipsDescendants = true
name.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
name.LayoutOrder = 1
name.Selectable = true
name.SelectionOrder = 1
name.Size = UDim2.fromScale(1, 1)
name.Text = "OPTIONS:"
name.TextColor3 = Color3.fromRGB(218, 218, 218)
name.TextSize = 18
name.Parent = header

local uICorner = Instance.new("UICorner")
uICorner.Name = "UICorner"
uICorner.Parent = header

local icon = Instance.new("ImageLabel")
icon.Name = "Icon"
icon.BackgroundTransparency = 1
icon.Image = "rbxassetid://115780670428316"
icon.Size = UDim2.fromScale(1, 1)
icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
icon.Parent = header

header.Parent = widget

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.BackgroundColor3 = Color3.fromRGB(172, 172, 172)
divider.BackgroundTransparency = 0.5
divider.LayoutOrder = 2
divider.Size = UDim2.new(1, 0, 0, 3)

local uICorner1 = Instance.new("UICorner")
uICorner1.Name = "UICorner"
uICorner1.Parent = divider

divider.Parent = widget

local options = Instance.new("ScrollingFrame")
options.Name = "Options"
options.Active = true
options.BackgroundTransparency = 1
options.CanvasSize = UDim2.new()
options.LayoutOrder = 3
options.ScrollBarImageColor3 = Color3.new()
options.ScrollBarImageTransparency = 0.3
options.ScrollBarThickness = 8
options.ScrollingDirection = Enum.ScrollingDirection.Y
options.Size = UDim2.new(1, 0, 0, 250)
options.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar

local uIListLayout3 = Instance.new("UIListLayout")
uIListLayout3.Name = "UIListLayout"
uIListLayout3.Padding = UDim.new(0, 8)
uIListLayout3.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout3.Parent = options

local uIPadding1 = Instance.new("UIPadding")
uIPadding1.Name = "UIPadding"
uIPadding1.PaddingBottom = UDim.new(0, 8)
uIPadding1.PaddingLeft = UDim.new(0, 8)
uIPadding1.PaddingRight = UDim.new(0, 8)
uIPadding1.PaddingTop = UDim.new(0, 8)
uIPadding1.Parent = options

options.Parent = widget

--

local function createTextBoxOption(order: number, optionsName: string, placeHolderText: string): (Frame, TextBox)
	local holder = Instance.new("Frame")
	holder.Name = optionsName
	holder.BackgroundColor3 = Color3.fromRGB(93, 93, 93)
	holder.BackgroundTransparency = 0.5
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, 0, 0, 26)

	local optionListLayout = Instance.new("UIListLayout")
	optionListLayout.Name = "UIListLayout"
	optionListLayout.FillDirection = Enum.FillDirection.Horizontal
	optionListLayout.Padding = UDim.new(0, 5)
	optionListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionListLayout.Parent = holder

	local optionInput = Instance.new("TextBox")
	optionInput.Name = "Input"
	optionInput.BackgroundTransparency = 1
	optionInput.ClearTextOnFocus = false
	optionInput.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	optionInput.LayoutOrder = 2
	optionInput.PlaceholderText = placeHolderText
	optionInput.SelectionOrder = 2
	optionInput.Size = UDim2.fromScale(0.5, 1)
	optionInput.Text = ""
	optionInput.TextColor3 = Color3.fromRGB(218, 218, 218)
	optionInput.TextSize = 16
	optionInput.TextXAlignment = Enum.TextXAlignment.Left
	optionInput.Parent = holder

	local optionName = Instance.new("TextLabel")
	optionName.Name = "Name"
	optionName.Active = true
	optionName.BackgroundTransparency = 1
	optionName.ClipsDescendants = true
	optionName.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	optionName.LayoutOrder = 1
	optionName.Selectable = true
	optionName.SelectionOrder = 1
	optionName.Size = UDim2.new(0.5, -5, 1, 0)
	optionName.Text = optionsName .. ":"
	optionName.TextColor3 = Color3.fromRGB(218, 218, 218)
	optionName.TextSize = 16
	optionName.Parent = holder

	local optionCorner = Instance.new("UICorner")
	optionCorner.Name = "UICorner"
	optionCorner.Parent = holder

	return holder, optionInput
end

local function forceOnlyNumbers(textbox: TextBox, limit: number?): RBXScriptConnection
	local realLimit = limit or 5
	local lastText = ""

	return textbox:GetPropertyChangedSignal("Text"):Connect(function()
		if #textbox.Text > realLimit then
			textbox.Text = lastText
			return
		end

		if textbox.Text == "" or tonumber(textbox.Text) then
			lastText = textbox.Text
		else
			textbox.Text = lastText
		end
	end)
end

--options
local portOption, portInput = createTextBoxOption(1, "Port", "Default: " .. Settings.GetDefaultPort())
forceOnlyNumbers(portInput)
portOption.Parent = options

-- This module handles the options panel UI and its interactions.
local OptionsPanel = {}

--returns the options widget so it can be manipulated by other modules
function OptionsPanel.GetOptionsWidget(): DockWidgetPluginGui
	return optionsWidget
end

--returns the port option frame and input textbox so they can be manipulated by other modules
function OptionsPanel.GetPortOption(): (Frame, TextBox)
	return portOption, portInput
end

return OptionsPanel
