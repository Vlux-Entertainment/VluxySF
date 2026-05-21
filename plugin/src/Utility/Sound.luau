--!strict

local SOUNDS = {
	CONNECT = "rbxassetid://116995696565929",
	DISCONNECT = "rbxassetid://116995696565929",
}

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

local widget = nil
if plugin then
	widget = plugin:CreateDockWidgetPluginGuiAsync(
		"VluxySF_soundPlayer",
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 10, 10, 10, 10)
	)
	widget.Name = "VluxySF_soundPlayer"
	widget.Title = "VluxySF Sound Player"
end

local Sound = {}

function Sound.PlayOneShot(soundId: string, adjust: (Sound) -> ()?)
	local sound = Instance.new("Sound")
	sound.Name = "VluxySFPluginSound"
	sound.SoundId = soundId
	sound.Parent = widget

	if adjust then
		adjust(sound)
	end

	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	sound:Play()
end

function Sound.PlayConnect()
	Sound.PlayOneShot(SOUNDS.CONNECT)
end

function Sound.PlayDisconnect()
	Sound.PlayOneShot(SOUNDS.DISCONNECT, function(sound)
		sound.PlaybackSpeed = 0.75
	end)
end

return Sound
