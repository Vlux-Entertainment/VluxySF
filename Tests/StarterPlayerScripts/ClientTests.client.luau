--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

VluxySF.Startup.InitClient()

task.wait(9999)

local iterations = {}
local function Test()
	local t = os.clock()

	for i, v in pairs(VluxySF.Schema.GetLocations()) do
		VluxySF.Fetch(v, nil, function(a0: Sound)
			a0.PlayOnRemove = false
		end)
	end
	for i = 1, 723 do
		VluxySF.Fetch("Summer Harvest")
	end

	table.insert(iterations, os.clock() - t)

	VluxySF.Schema.Get().UnattachedSounds:ClearAllChildren()
end

for i = 1, 50 do
	Test()
	print(iterations[i])

	task.wait(0.02)
end

local total = 0
for i, v in iterations do
	total += v
end
print("Average: " .. total / #iterations)
