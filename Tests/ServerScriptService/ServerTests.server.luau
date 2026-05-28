--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

local soundConfig = ServerStorage:FindFirstChild("SOUNDS")

-- local gameConfig = soundConfig.GAME

-- for i = 1, 1000 do
-- 	local sound = Instance.new("Sound")
-- 	sound.Name = `Sound` .. i
-- 	sound.SoundId = "rbxassetid://1835444509"
-- 	sound.Parent = gameConfig
-- end

VluxySF.Startup.InitServer(soundConfig)

print(VluxySF.Schema.Get())
