--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

VluxySF.Startup.WaitForSchema()

print(VluxySF.Schema.Get()) --test

task.wait(4)
VluxySF.Fetch("GunShot1")
