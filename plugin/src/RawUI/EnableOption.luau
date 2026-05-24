--!strict

--[[
    This module creates the UI for the settings tab. It returns a ScrollingFrame that you can parent your settings options to.

    The UI is created in a function so that it can be easily recreated when the plugin is enabled or disabled.
]]
local EnableOption = {}

--[[
    @param order number -- The order of the option in the settings UI.
    @param optionsName string -- The name of the option to display in the settings UI.
    @param startingValue boolean -- The starting value of the option.

    @return Frame -- The frame that contains the option. You should parent this to the settings UI.
    @return TextButton -- The button for the option. You can connect to its events to get when the option is toggled.
    @return (boolean) -> () -- A function that takes a boolean and sets the value of the option.
    @return () -> boolean -- A function that returns the current value of the option.

    Creates a new enable/disable option for the settings UI.
]]
function EnableOption.New(
	order: number,
	optionsName: string,
	startingValue: boolean
): (Frame, TextButton, (boolean) -> (), () -> boolean)
	local holder = Instance.new("Frame")
	holder.Name = optionsName
	holder.BackgroundColor3 = Color3.fromRGB(93, 93, 93)
	holder.BackgroundTransparency = 0.5
	holder.LayoutOrder = order
	holder.Size = UDim2.new(1, 0, 0, 26)

	local optionLayout = Instance.new("UIListLayout")
	optionLayout.Name = "UIListLayout"
	optionLayout.FillDirection = Enum.FillDirection.Horizontal
	optionLayout.Padding = UDim.new(0, 5)
	optionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionLayout.Parent = holder

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

	local optionHolder = Instance.new("Frame")
	optionHolder.Name = "Holder"
	optionHolder.Active = true
	optionHolder.BackgroundTransparency = 1
	optionHolder.ClipsDescendants = true
	optionHolder.LayoutOrder = 1
	optionHolder.Selectable = true
	optionHolder.SelectionOrder = 1
	optionHolder.Size = UDim2.new(0.5, -5, 1, 0)

	local optionPadding = Instance.new("UIPadding")
	optionPadding.Name = "UIPadding"
	optionPadding.PaddingBottom = UDim.new(0, 3)
	optionPadding.PaddingLeft = UDim.new(0, 3)
	optionPadding.PaddingRight = UDim.new(0, 3)
	optionPadding.PaddingTop = UDim.new(0, 3)
	optionPadding.Parent = optionHolder

	local optionInput = Instance.new("TextButton")
	optionInput.Name = "Input"
	optionInput.BackgroundColor3 = Color3.new(1, 1, 1)
	optionInput.BackgroundTransparency = 0.6
	optionInput.LayoutOrder = 2
	optionInput.SelectionOrder = 2
	optionInput.Size = UDim2.fromScale(1, 1)
	optionInput.SizeConstraint = Enum.SizeConstraint.RelativeYY
	optionInput.Text = ""
	optionInput.TextTransparency = 1

	local optionCorner2 = Instance.new("UICorner")
	optionCorner2.Name = "UICorner"
	optionCorner2.BottomLeftRadius = UDim.new(0, 6)
	optionCorner2.BottomRightRadius = UDim.new(0, 6)
	optionCorner2.TopLeftRadius = UDim.new(0, 6)
	optionCorner2.TopRightRadius = UDim.new(0, 6)
	optionCorner2.Parent = optionInput

	local optionsCheckMark = Instance.new("ImageLabel")
	optionsCheckMark.Name = "CheckMark"
	optionsCheckMark.AnchorPoint = Vector2.new(0.5, 0.5)
	optionsCheckMark.BackgroundTransparency = 1
	optionsCheckMark.ClipsDescendants = true
	optionsCheckMark.Image = "rbxassetid://71963744176364"
	optionsCheckMark.Interactable = false
	optionsCheckMark.Position = UDim2.fromScale(0.5, 0.5)
	optionsCheckMark.Size = UDim2.fromScale(0.9, 0.9)
	optionsCheckMark.ImageTransparency = 0.2
	optionsCheckMark.Visible = false
	optionsCheckMark.Parent = optionInput

	optionInput.Parent = optionHolder

	optionHolder.Parent = holder

	optionsCheckMark.Visible = startingValue
	optionInput.InputEnded:Connect(function()
		optionsCheckMark.Visible = not optionsCheckMark.Visible
	end)

	local function setState(state: boolean)
		optionsCheckMark.Visible = state
	end

	local function getState(): boolean
		return optionsCheckMark.Visible
	end

	return holder, optionInput, setState, getState
end

return EnableOption
