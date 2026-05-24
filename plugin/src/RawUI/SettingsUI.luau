--!strict

--[[
    This module creates the UI for the settings tab. It returns a ScrollingFrame that you can parent your settings options to.

    The UI is created in a function so that it can be easily recreated when the plugin is enabled or disabled.
]]
local SettingsUI = {}

--[[
    @param widget DockWidgetPluginGui -- The widget to put the settings UI in.

    @return ScrollingFrame -- The frame that contains all the settings options. You can parent your settings options to this frame.

    Creates the settings UI. You can parent your settings options to the returned ScrollingFrame.
]]
function SettingsUI.New(widget: DockWidgetPluginGui): ScrollingFrame
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
	name.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
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

	return options
end

return SettingsUI
