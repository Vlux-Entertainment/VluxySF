--!strict

--[[
	Three buttons for trying the library by ear in the test place. Every button plays a one-shot through
	FetchPlayOnce, so the sound destroys itself when it ends. The label under the buttons shows how many sounds are
	sitting in SoundService.UnattachedSounds, which should go back to zero after each sound finishes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

--Every button plays the warmed sound, so each press clones the template from the cache.
local WARMED_SOUND = "Whoosh"

local BUTTONS = {
	{ Label = "Lazy Load", Sound = WARMED_SOUND, Note = "cloned from the cache" },
	{ Label = "Load On Start", Sound = WARMED_SOUND, Note = "cloned from the cache" },
	{ Label = "Load From Warmup", Sound = WARMED_SOUND, Note = "cloned from the cache" },
}

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

------------------------------------------------------------------------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "VluxySFDemo"
screen.ResetOnSpawn = false

local frame = Instance.new("Frame")
frame.Name = "Buttons"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(180, 140)
frame.BackgroundTransparency = 1
frame.Parent = screen

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = frame

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, 0, 0, 36)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextStrokeTransparency = 0.5
status.TextSize = 14
status.TextWrapped = true
status.Font = Enum.Font.Gotham
status.Text = "Waiting for the schema..."
status.LayoutOrder = #BUTTONS + 1
status.Parent = frame

local function makeButton(order: number, label: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = label
	button.Size = UDim2.new(1, 0, 0, 26)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.TextColor3 = Color3.new(0, 0, 0)
	button.TextSize = 12
	button.Font = Enum.Font.Gotham
	button.Text = label
	button.LayoutOrder = order
	button.Parent = frame

	return button
end

------------------------------------------------------------------------------------------------------------------------

VluxySF.Startup.WaitForSchema()

local unattached = VluxySF.Schema.Get().UnattachedSounds

local function refreshStatus(message: string?)
	local count = #unattached:GetChildren()
	status.Text = `{message or "Ready."} Unattached sounds: {count}`
end

unattached.ChildAdded:Connect(function()
	refreshStatus()
end)
unattached.ChildRemoved:Connect(function()
	refreshStatus()
end)

--Warm one sound so the third button clones instead of builds. Warming happens once; Fetch keeps cloning it.
VluxySF.Cache.Warm(WARMED_SOUND)

for order, entry in ipairs(BUTTONS) do
	local button = makeButton(order, entry.Label)

	button.Activated:Connect(function()
		--One-shot: plays once and destroys itself when it ends.
		VluxySF.FetchPlayOnce(entry.Sound, nil, nil, true)

		refreshStatus(`{entry.Sound} ({entry.Note}).`)
	end)
end

refreshStatus()
screen.Parent = playerGui
