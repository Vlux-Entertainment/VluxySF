--!strict

local SOUNDS = {
	CONNECT = "rbxassetid://116995696565929",
	DISCONNECT = "rbxassetid://116995696565929",
}

------------------------------------------------------------------------------------------------------------------------

local plugin = plugin or script:FindFirstAncestorWhichIsA("Plugin") :: Plugin

------------------------------------------------------------------------------------------------------------------------

local widget = nil
if plugin then
	widget = plugin:CreateDockWidgetPluginGuiAsync(
		"VluxySF_soundPlayer",
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 10, 10, 10, 10)
	)
	widget.Name = "VluxySF_soundPlayer"
	widget.Title = "VluxySF Sound Player"
end

------------------------------------------------------------------------------------------------------------------------

--[[
	Utility for playing sounds in the plugin.
]]
local Sound = {}

--[[
	@param soundId string -- The asset id of the sound to play.
	@param adjust (Sound) -> ()? -- An optional function that can be used to adjust the sound before it plays.

	Plays a sound once. The sound will be automatically destroyed after it finishes playing.
]]
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

------------------------------------------------------------------------------------------------------------------------
--DIRECT_SOUNDS---------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	Plays the connect sound.
]]
function Sound.PlayConnect()
	Sound.PlayOneShot(SOUNDS.CONNECT)
end

--[[
	Plays the disconnect sound.
]]
function Sound.PlayDisconnect()
	Sound.PlayOneShot(SOUNDS.DISCONNECT, function(sound)
		sound.PlaybackSpeed = 0.75
	end)
end

return Sound
