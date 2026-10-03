--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local Expect = TestHarness.Expect
local ExpectContains = TestHarness.ExpectContains
local ExpectEqual = TestHarness.ExpectEqual
local ExpectNear = TestHarness.ExpectNear

--The sounds and groups authored in Tests/ServerStorage/TEST_SOUNDS.model.json
local FIXTURE_SOUNDS = { "BattleOne", "BattleTwo", "Click", "Explosion", "MainTheme" }
local FIXTURE_GROUPS = { "MUSIC", "SFX" }
local FIXTURE_PRELOADS = { "BattleOne", "BattleTwo", "Click" }

local JITTER_SAMPLES = 200

--[[
	Cases that must pass on both the server and the client once the schema is initialized.
]]
local SharedCases = {}

--[[
	@param suite TestHarness.Suite -- The suite to add the cases to.

	Runs every shared case. The schema has to be initialized first.
]]
function SharedCases.Run(suite: TestHarness.Suite)
	local schema = VluxySF.Schema.Get()

	--------------------------------------------------------------------------------------------------------------------
	--SCHEMA------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Schema lists every fixture sound", function()
		ExpectContains(VluxySF.Schema.GetNames(), FIXTURE_SOUNDS, "Schema.GetNames")
	end)

	suite.Test("Schema is frozen", function()
		Expect(table.isfrozen(schema), "The schema should be frozen")
		Expect(table.isfrozen(VluxySF.Schema.GetDefinitions()), "The definitions should be frozen")
	end)

	suite.Test("Definitions keep the authored properties", function()
		local definition = VluxySF.Schema.GetDefinition("MainTheme")
		assert(definition, "MainTheme should have a definition")

		local properties = definition.Properties :: { [string]: any }
		ExpectEqual(properties.Name, "MainTheme", "Name")
		ExpectEqual(properties.Looped, true, "Looped")
		ExpectNear(properties.Volume, 0.4, "Volume")
		ExpectEqual(definition.EffectsCount, 0, "EffectsCount")
	end)

	suite.Test("Preload names come from tagged sounds and tagged folders", function()
		ExpectContains(schema.PreloadNames, FIXTURE_PRELOADS, "PreloadNames")
		Expect(not table.find(schema.PreloadNames, "MainTheme"), "MainTheme is not tagged, so it should not preload")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--SOUND_GROUPS------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Each group Configuration becomes a SoundGroup", function()
		ExpectContains(VluxySF.Groups.GetNames(), FIXTURE_GROUPS, "Groups.GetNames")

		local container = schema.SoundGroupContainer
		ExpectEqual(container.Parent, SoundService, "Main SoundGroup parent")

		local music = VluxySF.Groups.GetByName("MUSIC")
		assert(music, "MUSIC should be a SoundGroup")

		ExpectEqual(music.Parent, container, "MUSIC parent")
		ExpectEqual(VluxySF.Groups.Get().MUSIC, music, "Groups.Get().MUSIC")
		ExpectEqual(VluxySF.Groups.GetByName("NOT_A_GROUP"), nil, "Unknown group")
	end)

	suite.Test("Group volumes can be set", function()
		local container = schema.SoundGroupContainer
		local music = VluxySF.Groups.GetByName("MUSIC") :: SoundGroup

		VluxySF.Groups.SetVolumes(0.5, { MUSIC = 0.25 })
		ExpectNear(container.Volume, 0.5, "Main volume")
		ExpectNear(music.Volume, 0.25, "MUSIC volume")

		VluxySF.Groups.SetMainVolume(1)
		VluxySF.Groups.SetVolumes(nil, { MUSIC = 1 })
		ExpectNear(container.Volume, 1, "Main volume after reset")
		ExpectNear(music.Volume, 1, "MUSIC volume after reset")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--FETCHING----------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Fetch rebuilds the authored sound", function()
		local sound = VluxySF.Fetch("MainTheme")

		Expect(sound:IsA("Sound"), "Fetch should return a Sound")
		ExpectEqual(sound.Name, "MainTheme", "Name")
		ExpectEqual(sound.Looped, true, "Looped")
		ExpectNear(sound.Volume, 0.4, "Volume")
		ExpectEqual(sound.SoundGroup, VluxySF.Groups.GetByName("MUSIC"), "SoundGroup")
		ExpectEqual(sound.Parent, schema.UnattachedSounds, "Parent of a sound fetched without one")

		sound:Destroy()
	end)

	suite.Test("Fetch parents the sound to the given parent", function()
		local parent = Instance.new("Folder")
		local sound = VluxySF.Fetch("Click", parent)

		ExpectEqual(sound.Parent, parent, "Parent")

		parent:Destroy()
	end)

	suite.Test("Fetch applies the preset, and a preset can set the parent", function()
		local parent = Instance.new("Folder")
		local preset = VluxySF.Presets.Combine(VluxySF.Presets.Volume(0.2), VluxySF.Presets.Parent(parent))

		local sound = VluxySF.Fetch("Click", nil, preset)

		ExpectNear(sound.Volume, 0.2, "Volume")
		ExpectEqual(sound.Parent, parent, "Parent")

		parent:Destroy()
	end)

	suite.Test("Fetch rebuilds sound effects under their class name", function()
		local sound = VluxySF.Fetch("Explosion")

		ExpectNear(sound.PlaybackSpeed, 1.2, "PlaybackSpeed")

		--The effect is named LongEcho in the fixture.
		local echo = sound:FindFirstChild("EchoSoundEffect")
		assert(echo and echo:IsA("EchoSoundEffect"), "Explosion should have an EchoSoundEffect")
		ExpectNear(echo.Delay, 0.5, "Echo delay")

		local reverb = sound:FindFirstChild("ReverbSoundEffect")
		Expect(reverb and reverb:IsA("ReverbSoundEffect"), "Explosion should have a ReverbSoundEffect")

		sound:Destroy()
	end)

	suite.Test("Fetch returns a blank sound for an unknown name (warnings expected)", function()
		local sound = VluxySF.Fetch("NotARealSound")

		Expect(sound:IsA("Sound"), "Fetch should still return a Sound")
		ExpectEqual(sound.Name, "VluxySF_Blank_Sound", "Name")

		sound:Destroy()
	end)

	suite.Test("FetchStrict returns nil for an unknown name (warnings expected)", function()
		ExpectEqual(VluxySF.FetchStrict("NotARealSound"), nil, "Unknown sound")

		local sound = VluxySF.FetchStrict("Click")
		assert(sound, "FetchStrict should find Click")

		sound:Destroy()
	end)

	suite.Test("FetchPlayOnce stops looping and its cleanup destroys the sound", function()
		local captured: { Sound } = {}

		local cleanup = VluxySF.FetchPlayOnce("MainTheme", nil, function(sound: Sound)
			table.insert(captured, sound)
		end)

		local sound = captured[1]
		assert(sound, "The preset should have received the sound")
		ExpectEqual(sound.Looped, false, "Looped")

		cleanup()
		ExpectEqual(sound.Parent, nil, "Parent after cleanup")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--CONVERSIONS-------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Conversions round trip a sound and its effects", function()
		local original = Instance.new("Sound")
		original.Name = "RoundTrip"
		original.Volume = 0.3

		local pitch = Instance.new("PitchShiftSoundEffect")
		pitch.Octave = 1.5
		pitch.Parent = original

		local definition = VluxySF.Conversions.ToDefinition(original)
		ExpectEqual((definition.Properties :: { [string]: any }).Name, "RoundTrip", "Definition name")
		ExpectEqual(definition.EffectsCount, 1, "EffectsCount")

		local rebuilt = VluxySF.Conversions.FromDefinition(definition)
		ExpectEqual(rebuilt.Name, "RoundTrip", "Rebuilt name")
		ExpectNear(rebuilt.Volume, 0.3, "Rebuilt volume")

		local rebuiltPitch = rebuilt:FindFirstChild("PitchShiftSoundEffect")
		assert(rebuiltPitch and rebuiltPitch:IsA("PitchShiftSoundEffect"), "The effect should be rebuilt")
		ExpectNear(rebuiltPitch.Octave, 1.5, "Rebuilt octave")

		original:Destroy()
		rebuilt:Destroy()
	end)

	--------------------------------------------------------------------------------------------------------------------
	--PRESETS_AND_JITTER------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Combined presets apply in order", function()
		local sound = Instance.new("Sound")
		local preset = VluxySF.Presets.Combine(
			VluxySF.Presets.Volume(0.1),
			VluxySF.Presets.PlaybackSpeed(1.3),
			VluxySF.Presets.Volume(0.9)
		)

		preset(sound)

		ExpectNear(sound.Volume, 0.9, "Volume")
		ExpectNear(sound.PlaybackSpeed, 1.3, "PlaybackSpeed")

		sound:Destroy()
	end)

	suite.Test("Jitter stays inside its range", function()
		local function expectInRange(label: string, jitter: () -> number, min: number, max: number)
			for _ = 1, JITTER_SAMPLES do
				local value = jitter()

				Expect(value >= min and value <= max, `Jitter.{label} gave {value}, outside {min} to {max}`)
			end
		end

		expectInRange("Default", VluxySF.Jitter.Default(1, 0.2), 0.8, 1.2)
		expectInRange("Range", VluxySF.Jitter.Range(0.5, 0.6), 0.5, 0.6)
		expectInRange("Scale", VluxySF.Jitter.Scale(0.1), 0.9, 1.1)
		expectInRange("UnitLog", VluxySF.Jitter.UnitLog(1, 0.2), 0.8, 1.2)

		--Every jitter is clamped from 0 to 10.
		expectInRange("Default near 10", VluxySF.Jitter.Default(10, 5), 5, 10)
		expectInRange("Default near 0", VluxySF.Jitter.Default(0, 5), 0, 5)
	end)

	--------------------------------------------------------------------------------------------------------------------
	--STARTUP-----------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Startup reports the schema as ready", function()
		ExpectEqual(VluxySF.Startup.IsInitialized(), true, "IsInitialized")

		--Returns right away when the schema is ready.
		VluxySF.Startup.WaitForSchema()

		local ran = false
		VluxySF.Startup.ConnectForSchema(function()
			ran = true
		end)

		ExpectEqual(ran, true, "ConnectForSchema callback ran")
	end)
end

return SharedCases
