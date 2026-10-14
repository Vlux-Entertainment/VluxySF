--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local Expect = TestHarness.Expect
local ExpectContains = TestHarness.ExpectContains
local ExpectEqual = TestHarness.ExpectEqual
local ExpectError = TestHarness.ExpectError
local ExpectNear = TestHarness.ExpectNear

--The sounds and groups authored in Tests/ServerStorage/TEST_SOUNDS.model.json
--Whoosh sits inside a Model, which proves any container under a group is walked. It is silent, has PlayOnRemove on and
--was saved with a TimePosition, for the cases about playback state.
local FIXTURE_SOUNDS = { "BattleOne", "BattleTwo", "Click", "Explosion", "MainTheme", "Whoosh" }
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
	local schema = assert(VluxySF.Schema.Get(), "The schema should be ready before the shared cases run")

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
		ExpectEqual(properties.RollOffMode, Enum.RollOffMode.Linear, "RollOffMode")
		ExpectEqual(properties.LoopRegion, NumberRange.new(1, 3), "LoopRegion")
		ExpectEqual(properties.SoundGroup, VluxySF.Groups.Get("MUSIC"), "SoundGroup")
		ExpectEqual(definition.EffectsCount, 0, "EffectsCount")

		Expect(table.isfrozen(definition), "The definition should be frozen")
		Expect(table.isfrozen(definition.Properties), "The properties should be frozen")
	end)

	suite.Test("Definitions leave default properties out", function()
		local definition = VluxySF.Schema.GetDefinition("Click")
		assert(definition, "Click should have a definition")

		local properties = definition.Properties :: { [string]: any }
		ExpectEqual(properties.Looped, nil, "Looped is the default, so it should not be stored")
		ExpectEqual(properties.PlaybackSpeed, nil, "PlaybackSpeed is the default, so it should not be stored")
		ExpectEqual(properties.Pitch, nil, "Pitch is deprecated, so it should never be stored")
		ExpectEqual(properties.ClassName, nil, "ClassName should not be stored")
		ExpectEqual(properties.Parent, nil, "Parent should not be stored")
	end)

	suite.Test("Definitions never keep playback state", function()
		local definition = VluxySF.Schema.GetDefinition("Whoosh")
		assert(definition, "Whoosh should have a definition")

		local properties = definition.Properties :: { [string]: any }
		ExpectEqual(properties.TimePosition, nil, "TimePosition was authored but is runtime state")
		ExpectEqual(properties.Playing, nil, "Playing is never stored")
		ExpectEqual(properties.PlayOnRemove, true, "PlayOnRemove is a real property and is kept")

		local sound = VluxySF.Fetch("Whoosh")
		ExpectEqual(sound.Playing, false, "A fetched sound is stopped")
		ExpectEqual(sound.TimePosition, 0, "A fetched sound starts at 0")
		ExpectEqual(sound.PlayOnRemove, true, "PlayOnRemove on the fetched sound")

		sound:Destroy()
	end)

	suite.Test("GetDefinition returns the same frozen table every time", function()
		ExpectEqual(VluxySF.Schema.GetDefinition("Click"), VluxySF.Schema.GetDefinition("Click"), "Definition")
		ExpectEqual(VluxySF.Schema.GetDefinitions().Click, VluxySF.Schema.GetDefinition("Click"), "GetDefinitions")
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

		local music = VluxySF.Groups.Get("MUSIC")
		assert(music, "MUSIC should be a SoundGroup")

		ExpectEqual(music.Parent, container, "MUSIC parent")
		ExpectEqual(VluxySF.Groups.GetAll().MUSIC, music, "Groups.GetAll().MUSIC")
		ExpectEqual(VluxySF.Groups.Get("NOT_A_GROUP"), nil, "Unknown group")
	end)

	suite.Test("Group volumes can be set", function()
		local container = schema.SoundGroupContainer
		local music = VluxySF.Groups.Get("MUSIC") :: SoundGroup

		VluxySF.Groups.SetMainVolume(0.5)
		VluxySF.Groups.SetVolumes({ MUSIC = 0.25 })
		ExpectNear(container.Volume, 0.5, "Main volume")
		ExpectNear(music.Volume, 0.25, "MUSIC volume")
		ExpectNear(VluxySF.Groups.GetMainVolume(), 0.5, "GetMainVolume")
		ExpectNear(VluxySF.Groups.GetVolumes().MUSIC, 0.25, "GetVolumes().MUSIC")

		VluxySF.Groups.SetVolume("MUSIC", 0.75)
		ExpectNear(music.Volume, 0.75, "SetVolume")

		VluxySF.Groups.SetMainVolume(1)
		VluxySF.Groups.SetVolumes({ MUSIC = 1 })
		ExpectNear(container.Volume, 1, "Main volume after reset")
		ExpectNear(music.Volume, 1, "MUSIC volume after reset")
	end)

	suite.Test("Groups list in schema order and give the main group", function()
		local names = VluxySF.Groups.GetNames()
		ExpectEqual(names[1], FIXTURE_GROUPS[1], "First group")
		ExpectEqual(names[2], FIXTURE_GROUPS[2], "Second group")
		ExpectEqual(VluxySF.Groups.GetMain(), schema.SoundGroupContainer, "GetMain")
	end)

	suite.Test("Bad volumes are ignored with a warning (warnings expected)", function()
		local music = VluxySF.Groups.Get("MUSIC") :: SoundGroup

		VluxySF.Groups.SetVolume("MUSIC", -1)
		VluxySF.Groups.SetVolume("MUSIC", 0 / 0)
		VluxySF.Groups.SetVolume("MUSIC", "loud" :: any)
		VluxySF.Groups.SetVolume("MUSIC", 11)
		VluxySF.Groups.SetVolume("NOT_A_GROUP", 0.5)
		VluxySF.Groups.SetVolumes(nil :: any)
		VluxySF.Groups.SetMainVolume(-5)

		ExpectNear(music.Volume, 1, "MUSIC volume is unchanged")
		ExpectNear(VluxySF.Groups.GetMainVolume(), 1, "Main volume is unchanged")
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
		ExpectEqual(sound.RollOffMode, Enum.RollOffMode.Linear, "RollOffMode")
		ExpectEqual(sound.LoopRegion, NumberRange.new(1, 3), "LoopRegion")
		ExpectEqual(sound.SoundGroup, VluxySF.Groups.Get("MUSIC"), "SoundGroup")
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

	suite.Test("Fetch ignores a parent that is not an Instance (warnings expected)", function()
		local sound = VluxySF.Fetch("Click", "workspace" :: any)
		ExpectEqual(sound.Parent, schema.UnattachedSounds, "Fetch with a string parent")
		sound:Destroy()

		local tried = VluxySF.TryFetch("Click", 42 :: any)
		assert(tried, "TryFetch should still find Click")
		ExpectEqual(tried.Parent, schema.UnattachedSounds, "TryFetch with a number parent")
		tried:Destroy()

		local before = #schema.UnattachedSounds:GetChildren()
		VluxySF.OneShot("Click", true :: any, VluxySF.Presets.Volume(0))()
		ExpectEqual(#schema.UnattachedSounds:GetChildren(), before, "OneShot with a boolean parent cleans up")
	end)

	suite.Test("Fetch ignores a preset that is not a function (warnings expected)", function()
		local sound = VluxySF.Fetch("Click", nil, "quiet" :: any)
		ExpectNear(sound.Volume, 0.8, "The authored volume is kept")
		ExpectEqual(sound.Parent, schema.UnattachedSounds, "Parent")
		sound:Destroy()

		local tried = VluxySF.TryFetch("Click", nil, {} :: any)
		assert(tried, "TryFetch should still find Click")
		tried:Destroy()
	end)

	suite.Test("Fetch into a destroyed parent does not throw", function()
		local gone = Instance.new("Folder")
		gone:Destroy()

		local sound = VluxySF.Fetch("Click", gone)
		Expect(sound:IsA("Sound"), "Fetch should return a Sound")
		Expect(
			sound.Parent == gone or sound.Parent == schema.UnattachedSounds,
			"The sound is in the given parent or fell back to UnattachedSounds"
		)

		sound:Destroy()
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

	suite.Test("TryFetch returns nil for an unknown name (warnings expected)", function()
		ExpectEqual(VluxySF.TryFetch("NotARealSound"), nil, "Unknown sound")

		local sound = VluxySF.TryFetch("Click")
		assert(sound, "TryFetch should find Click")

		sound:Destroy()
	end)

	suite.Test("OneShot with an unknown name leaves nothing behind (warnings expected)", function()
		local before = #schema.UnattachedSounds:GetChildren()

		local cleanup = VluxySF.OneShot("NotARealSound")
		cleanup()

		ExpectEqual(#schema.UnattachedSounds:GetChildren(), before, "UnattachedSounds count")
	end)

	suite.Test("OneShot stops looping and its cleanup destroys the sound", function()
		local captured: { Sound } = {}

		local cleanup = VluxySF.OneShot("MainTheme", nil, function(sound: Sound)
			table.insert(captured, sound)
		end)

		local sound = captured[1]
		assert(sound, "The preset should have received the sound")
		ExpectEqual(sound.Looped, false, "Looped")

		cleanup()
		ExpectEqual(sound.Parent, nil, "Parent after cleanup")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--WRAPPING----------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	type FakeWrapper = { Sound: Sound, Kind: string }

	local function fakeWrap(sound: Sound): FakeWrapper
		return { Sound = sound, Kind = "FakeWrapper" }
	end

	local Wrapped = VluxySF.WithWrapper(fakeWrap)

	suite.Test("WithWrapper passes fetched sounds through the wrapper", function()
		local wrapped = Wrapped.Fetch("MainTheme")

		ExpectEqual(wrapped.Kind, "FakeWrapper", "Kind")
		ExpectEqual(wrapped.Sound.Name, "MainTheme", "Wrapped sound")
		ExpectEqual(wrapped.Sound.Parent, schema.UnattachedSounds, "Parent of a sound fetched without one")

		wrapped.Sound:Destroy()
	end)

	suite.Test("WithWrapper applies presets and parents before wrapping", function()
		local parent = Instance.new("Folder")
		local wrapped = Wrapped.Fetch("Click", parent, VluxySF.Presets.Volume(0.2))

		ExpectNear(wrapped.Sound.Volume, 0.2, "Volume")
		ExpectEqual(wrapped.Sound.Parent, parent, "Parent")

		parent:Destroy()
	end)

	suite.Test("WithWrapper wraps the blank sound for an unknown name (warnings expected)", function()
		local wrapped = Wrapped.Fetch("NotARealSound")

		ExpectEqual(wrapped.Kind, "FakeWrapper", "Kind")
		ExpectEqual(wrapped.Sound.Name, "VluxySF_Blank_Sound", "Wrapped sound")

		wrapped.Sound:Destroy()
	end)

	suite.Test("WithWrapper TryFetch returns nil without calling the wrapper (warnings expected)", function()
		local calls = 0
		local counting = VluxySF.WithWrapper(function(sound: Sound): Sound
			calls += 1

			return sound
		end)

		ExpectEqual(counting.TryFetch("NotARealSound"), nil, "Unknown sound")
		ExpectEqual(calls, 0, "Wrapper calls for an unknown sound")

		local sound = counting.TryFetch("Click")
		assert(sound, "TryFetch should find Click")
		ExpectEqual(calls, 1, "Wrapper calls for a known sound")

		sound:Destroy()
	end)

	suite.Test("WithWrapper leaves the library itself unchanged", function()
		Expect(table.isfrozen(Wrapped), "The wrapped library should be frozen")
		ExpectEqual(Wrapped.Startup, VluxySF.Startup, "Startup")
		ExpectEqual(Wrapped.Groups, VluxySF.Groups, "Groups")
		ExpectEqual(Wrapped.OneShot, VluxySF.OneShot, "OneShot")

		local sound = VluxySF.Fetch("Click")
		Expect(sound:IsA("Sound"), "VluxySF.Fetch should still return a Sound")

		sound:Destroy()
	end)

	suite.Test("WithWrapper refuses something that is not a function", function()
		ExpectError(function()
			VluxySF.WithWrapper(nil :: any)
		end, "WithWrapper(nil)")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--FAILURES_AND_LEAKS------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	local function unattachedCount(): number
		return #schema.UnattachedSounds:GetChildren()
	end

	suite.Test("Fetching and destroying many sounds leaves nothing behind", function()
		local before = unattachedCount()

		for _ = 1, 200 do
			VluxySF.Fetch("Explosion"):Destroy()
		end

		ExpectEqual(unattachedCount(), before, "UnattachedSounds count")
	end)

	suite.Test("OneShot cleanups leave nothing behind", function()
		local before = unattachedCount()
		local mute = VluxySF.Presets.Volume(0)

		local cleanups: { () -> () } = {}
		for _ = 1, 50 do
			table.insert(cleanups, VluxySF.OneShot("Click", nil, mute))
		end
		for _, cleanup in ipairs(cleanups) do
			cleanup()
		end

		ExpectEqual(unattachedCount(), before, "UnattachedSounds count")
	end)

	suite.Test("A preset that errors raises to the caller and leaves nothing behind", function()
		local before = unattachedCount()

		ExpectError(function()
			VluxySF.Fetch("Click", nil, function()
				error("preset failed")
			end)
		end, "Fetch with a failing preset")

		ExpectEqual(unattachedCount(), before, "UnattachedSounds count")
	end)

	suite.Test("WithWrapper destroys the sound when the wrapper errors", function()
		local failing = VluxySF.WithWrapper(function(_sound: Sound): Sound
			error("wrapper failed")
		end)
		local before = unattachedCount()

		ExpectError(function()
			failing.Fetch("Click")
		end, "Fetch with a failing wrapper")
		ExpectError(function()
			failing.TryFetch("Click")
		end, "TryFetch with a failing wrapper")

		ExpectEqual(unattachedCount(), before, "UnattachedSounds count")
	end)

	suite.Test("Fetch with a name that is not a string does not throw (warnings expected)", function()
		local sound = VluxySF.Fetch(nil :: any)
		ExpectEqual(sound.Name, "VluxySF_Blank_Sound", "Fetch(nil)")
		sound:Destroy()

		ExpectEqual(VluxySF.TryFetch(42 :: any), nil, "TryFetch(42)")
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

	suite.Test("Conversions leave playback state out", function()
		local original = Instance.new("Sound")
		original.Name = "Seeked"
		original.TimePosition = 2

		local definition = VluxySF.Conversions.ToDefinition(original)
		ExpectEqual((definition.Properties :: { [string]: any }).TimePosition, nil, "TimePosition")
		ExpectEqual((definition.Properties :: { [string]: any }).Playing, nil, "Playing")

		original:Destroy()
	end)

	suite.Test("Conversions warn and give blanks for bad input (warnings expected)", function()
		local fromNil = VluxySF.Conversions.ToDefinition(nil :: any)
		ExpectEqual((fromNil.Properties :: { [string]: any }).Name, "VluxySF_Blank_Sound", "ToDefinition(nil)")
		ExpectEqual(fromNil.EffectsCount, 0, "ToDefinition(nil) effects")

		local fromFolder = VluxySF.Conversions.ToDefinition(Instance.new("Folder") :: any)
		ExpectEqual((fromFolder.Properties :: { [string]: any }).Name, "VluxySF_Blank_Sound", "ToDefinition(Folder)")

		local blank = VluxySF.Conversions.FromDefinition(nil :: any)
		ExpectEqual(blank.Name, "VluxySF_Blank_Sound", "FromDefinition(nil)")
		blank:Destroy()

		local noProperties = VluxySF.Conversions.FromDefinition({ Properties = 5 } :: any)
		ExpectEqual(noProperties.Name, "VluxySF_Blank_Sound", "FromDefinition without a Properties table")
		noProperties:Destroy()

		--a bad effect entry is skipped, the rest of the definition is built
		local partly = VluxySF.Conversions.FromDefinition({
			Properties = { Name = "Partly" },
			Effects = { EchoSoundEffect = 5, ReverbSoundEffect = { WetLevel = 1 } },
		} :: any)
		ExpectEqual(partly.Name, "Partly", "Name with a bad effect entry")
		ExpectEqual(partly:FindFirstChild("EchoSoundEffect"), nil, "The bad effect is skipped")
		Expect(partly:FindFirstChild("ReverbSoundEffect"), "The good effect is built")
		partly:Destroy()
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

		expectInRange("Uniform", VluxySF.Jitter.Uniform(1, 0.2), 0.8, 1.2)
		expectInRange("Range", VluxySF.Jitter.Range(0.5, 0.6), 0.5, 0.6)
		expectInRange("Natural", VluxySF.Jitter.Natural(1, 0.2), 0.8, 1.2)

		--Values never go below 0, and there is no upper clamp.
		expectInRange("Uniform near 0", VluxySF.Jitter.Uniform(0, 5), 0, 5)
		expectInRange("Uniform above 10", VluxySF.Jitter.Uniform(20, 5), 15, 25)
	end)

	suite.Test("Jitter builders fall back on bad arguments instead of throwing (warnings expected)", function()
		local Jitter = VluxySF.Jitter

		ExpectEqual(Jitter.Uniform("a" :: any, "b" :: any)(), 1, "Uniform with no numbers gives 1")
		ExpectEqual(Jitter.Uniform(1, 0 / 0)(), 1, "Uniform with a NaN spread gives the center")
		ExpectEqual(Jitter.Natural(0.7, nil :: any)(), 0.7, "Natural with no spread gives the center")
		ExpectEqual(Jitter.Range(nil :: any, 0.4)(), 0.4, "Range with one bound gives that bound")
		ExpectEqual(Jitter.Range(0 / 0, math.huge)(), 1, "Range with no usable bound gives 1")

		--reversed bounds are swapped, not thrown about inside a later fetch
		local swapped = Jitter.Range(0.6, 0.5)
		for _ = 1, JITTER_SAMPLES do
			local value = swapped()
			Expect(value >= 0.5 and value <= 0.6, `Jitter.Range(0.6, 0.5) gave {value}`)
		end
	end)

	suite.Test("Preset builders given bad arguments return a preset that does nothing (warnings expected)", function()
		local Presets = VluxySF.Presets
		local sound = Instance.new("Sound")

		local doNothings: { [string]: (Sound) -> () } = {
			Volume = Presets.Volume("loud" :: any),
			PlaybackSpeed = Presets.PlaybackSpeed(0 / 0),
			Parent = Presets.Parent("workspace" :: any),
			NaturalVolumeJitter = Presets.NaturalVolumeJitter("a" :: any),
			NaturalPlaybackJitter = Presets.NaturalPlaybackJitter(nil, math.huge),
			RandomVolumeJitter = Presets.RandomVolumeJitter({} :: any, 0.1),
			RandomPlaybackJitter = Presets.RandomPlaybackJitter(1, "b" :: any),
		}
		for label, preset in pairs(doNothings) do
			ExpectEqual(type(preset), "function", `Presets.{label} should still return a preset`)
			preset(sound)
		end

		ExpectNear(sound.Volume, 0.5, "Volume is untouched")
		ExpectNear(sound.PlaybackSpeed, 1, "PlaybackSpeed is untouched")
		ExpectEqual(sound.Parent, nil, "Parent is untouched")

		--Combine leaves out what is not a function and keeps the rest in order
		Presets.Combine(Presets.Volume(0.2), nil :: any, "x" :: any, Presets.PlaybackSpeed(1.5))(sound)
		ExpectNear(sound.Volume, 0.2, "Volume from Combine")
		ExpectNear(sound.PlaybackSpeed, 1.5, "PlaybackSpeed from Combine")

		sound:Destroy()
	end)

	--------------------------------------------------------------------------------------------------------------------
	--STARTUP-----------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Startup reports the schema as ready", function()
		ExpectEqual(VluxySF.Startup.IsReady(), true, "IsReady")

		--Returns right away when the schema is ready.
		VluxySF.Startup.WaitUntilReady()

		local ran = false
		VluxySF.Startup.OnReady(function()
			ran = true
		end)

		ExpectEqual(ran, true, "OnReady callback ran")
	end)
end

return SharedCases
