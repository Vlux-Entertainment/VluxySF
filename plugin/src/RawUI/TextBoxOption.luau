--!strict

--[[
    This module creates the UI for the settings tab. It returns a ScrollingFrame that you can parent your settings options to.

    The UI is created in a function so that it can be easily recreated when the plugin is enabled or disabled.
]]
local TextBoxOption = {}

--[[
    @param order number -- The order of the option in the settings UI.
    @param optionsName string -- The name of the option to display in the settings UI.
    @param placeHolderText string -- The placeholder text for the TextBox.

    @return Frame -- The frame that contains the option. You should parent this to the settings UI.
    @return TextBox -- The TextBox for the option. You can connect to its events to get the value of the option.

    Creates a new TextBox option for the settings UI.
]]
function TextBoxOption.New(
	order: number,
	optionsName: string,
	currentText: string?,
	placeHolderText: string
): (Frame, TextBox)
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
	optionInput.Text = currentText or ""
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

--[[
    @param textbox TextBox -- The TextBox to force only numbers in.
    @param limit number? -- The maximum number of characters allowed in the TextBox. Defaults to 5.

    @return RBXScriptConnection -- The connection to the event. You can disconnect this when you no longer need it.

    Forces the TextBox to only allow numbers. If the user tries to enter a non-number, it will revert to the last valid text. It also limits the number of characters that can be entered.
]]
function TextBoxOption.ForceOnlyNumbers(textbox: TextBox, limit: number?): RBXScriptConnection
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

return TextBoxOption
