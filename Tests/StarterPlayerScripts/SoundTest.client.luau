--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

VluxySF.Startup.WaitForSchema()

task.wait(5)

VluxySF.FetchPlayOnce("introWarn")
