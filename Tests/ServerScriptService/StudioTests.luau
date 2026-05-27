--!strict

--require(game:GetService("ServerScriptService").StudioTests)

local ServerStorage = game:GetService("ServerStorage")

local StudioTests = {}

function StudioTests.CreateFakeFolders(folders: number?, sounds: number?)
	local folderCount, soundCount = folders or 20, sounds or 40

	local currentSoundCount = 0

	local soundConfig = ServerStorage:FindFirstChild("SOUNDS")

	local startFolder = Instance.new("Folder")
	startFolder.Name = "TestsFolder"
	startFolder.Parent = soundConfig.GAME

	local prevFolder = startFolder
	for i = 1, folderCount do
		task.wait(0.01)

		local folder = Instance.new("Folder")
		folder.Name = "SoundFolder" .. i
		folder.Parent = prevFolder
		prevFolder = folder

		for i2 = 1, soundCount do
			local sound = Instance.new("Sound")
			sound.Name = "SoundTest" .. i2 + currentSoundCount
			sound.SoundId = "rbxassetid://5037969255"
			sound.Parent = folder
		end

		currentSoundCount += soundCount
	end

	print(`Created {folderCount} folders with {currentSoundCount} sounds total.`)
end

return StudioTests
