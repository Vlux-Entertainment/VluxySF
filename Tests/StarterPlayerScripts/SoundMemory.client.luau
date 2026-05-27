--!strict

--[[
    audio sizes for testing:
    -100KB
    --500KB
    --1MB
    --2MB
    --5MB
    --10MB
]]

--[[
    There should be 5 of each memory size, so 30 sounds total.

    There should also be a folder of 100 sounds all of various sizes to fully test.

    Need to see when sounds are

    Need to test preloading too


    Ask question about preloading audio and it not showing up in the scene analysis tool.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.VluxySF)

VluxySF.Startup.WaitForSchema()

task.wait(9999)

for _, soundName in pairs(VluxySF.Schema.GetLocations()) do
	task.spawn(function()
		local t = 0

		local passes = 10
		local iterations = 1000

		local soundForInfo = VluxySF.Fetch(soundName)
		if not soundForInfo then
			warn(`{soundForInfo} for info failed!`)
			return
		end

		if not soundForInfo.IsLoaded then
			soundForInfo.Loaded:Wait()
		end

		for k = 1, passes do
			for i = 1, iterations do
				local newSound = VluxySF.Fetch(soundName)
				if not newSound then
					warn(`{newSound} was not created for test!`)
					continue
				end

				if not newSound.IsLoaded then
					local t2 = os.clock()

					newSound.Loaded:Wait()

					t += os.clock() - t2
				end
				newSound:Destroy()
			end

			task.wait()
		end

		--t /= passes

		local denominator = soundForInfo.TimeLength == 0 and 1 or soundForInfo.TimeLength
		print(`"{soundName}", LoadTime: {t}, Length: {soundForInfo.TimeLength}, Ratio: {t / denominator}!`)

		soundForInfo:Destroy()
	end)
end

--VluxySF.Fetch("The Call (Intro)")
