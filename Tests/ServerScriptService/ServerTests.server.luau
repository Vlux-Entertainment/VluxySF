--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

local soundConfig = ServerStorage:FindFirstChild("SOUNDS")

VluxySF.Startup.InitServer(soundConfig)
