--!strict

--[[
	Adds a large group of sounds to the test fixture, for checking how the library handles big sound folders.

	Run this from the command bar in edit mode, then press Play:
		require(game:GetService("ServerScriptService").StressFixture).Create()

	The sounds are added to the place, not to the files, so they are gone once Rojo syncs the fixture again.
]]
local ServerStorage = game:GetService("ServerStorage")

local GROUP_NAME = "STRESS"
local SOUND_ID = "rbxasset://sounds/clickfast.wav"

local StressFixture = {}

--[[
	@param folders number? -- How many nested folders to create. Default is 20.
	@param sounds number? -- How many sounds to put in each folder. Default is 40.

	Creates the STRESS group with nested folders of sounds named StressSound1, StressSound2, ...
]]
function StressFixture.Create(folders: number?, sounds: number?)
	local folderCount: number, soundCount: number = folders or 20, sounds or 40

	local soundConfig = ServerStorage:FindFirstChild("TEST_SOUNDS")
	assert(soundConfig, "TEST_SOUNDS was not found in ServerStorage! Sync the test place first.")

	local oldGroup = soundConfig:FindFirstChild(GROUP_NAME)
	if oldGroup then
		oldGroup:Destroy()
	end

	local group = Instance.new("Configuration")
	group.Name = GROUP_NAME

	local currentSoundCount = 0

	local parent: Instance = group
	for folderIndex = 1, folderCount do
		local folder = Instance.new("Folder")
		folder.Name = "StressFolder" .. folderIndex
		folder.Parent = parent
		parent = folder

		for soundIndex = 1, soundCount do
			local sound = Instance.new("Sound")
			sound.Name = "StressSound" .. currentSoundCount + soundIndex
			sound.SoundId = SOUND_ID
			sound.Parent = folder
		end

		currentSoundCount += soundCount
	end

	group.Parent = soundConfig

	print(`[VluxySF Tests] Created {folderCount} folders with {currentSoundCount} sounds in {GROUP_NAME}.`)
end

return StressFixture
