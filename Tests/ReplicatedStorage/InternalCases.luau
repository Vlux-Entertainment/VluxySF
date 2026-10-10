--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestHarness = require(ReplicatedStorage.TestHarness)

local library = ReplicatedStorage.VluxySF
local Codec = require(library.Core.Codec)
local Compile = require(library.Core.Compile)
local Converters = require(library.Core.Converters)
local Properties = require(library.Core.Properties)

local Expect = TestHarness.Expect
local ExpectEqual = TestHarness.ExpectEqual
local ExpectError = TestHarness.ExpectError
local ExpectNear = TestHarness.ExpectNear

local LARGE_SCHEMA_SOUNDS = 2000

--[[
	Cases for the core modules that the public API does not reach directly: the codec, property reading, and the
	compile walk. They do not need the schema, so they run on both sides.
]]
local InternalCases = {}

------------------------------------------------------------------------------------------------------------------------

local function makeSound(name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxasset://sounds/clickfast.wav"

	return sound
end

--[[
	@param suite TestHarness.Suite -- The suite to add the cases to.

	Runs every internal case.
]]
function InternalCases.Run(suite: TestHarness.Suite)
	--------------------------------------------------------------------------------------------------------------------
	--CODEC-------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Codec round trips every value type and the effects", function()
		local writer = Codec.NewWriter()

		Codec.WriteDefinition(writer, "Full", 2, {
			Properties = {
				Name = "Full",
				SoundId = "rbxassetid://123",
				Volume = 0.25,
				Looped = true,
				RollOffMode = Enum.RollOffMode.Linear,
				LoopRegion = NumberRange.new(1.5, 2.5),
			} :: any,
			Effects = {
				EchoSoundEffect = { Name = "EchoSoundEffect", Delay = 0.75, Enabled = false },
			} :: any,
			EffectsCount = 1,
		})
		Codec.WriteDefinition(
			writer,
			"Bare",
			0,
			{ Properties = { Name = "Bare" } :: any, Effects = {} :: any, EffectsCount = 0 }
		)

		local loaded = Codec.Load(Codec.Finish(writer, { "MUSIC", "SFX" }, { "Full" }))

		ExpectEqual(loaded.Count, 2, "Count")
		ExpectEqual(loaded.GroupNames[2], "SFX", "GroupNames")
		ExpectEqual(loaded.PreloadNames[1], "Full", "PreloadNames")
		ExpectEqual(loaded.Names[1], "Full", "Names order")

		local full, fullGroup = Codec.ReadDefinition(loaded, loaded.Offsets.Full)
		local properties = full.Properties :: { [string]: any }
		ExpectEqual(fullGroup, 2, "Group index")
		ExpectEqual(properties.Name, "Full", "Name")
		ExpectEqual(properties.SoundId, "rbxassetid://123", "SoundId")
		ExpectNear(properties.Volume, 0.25, "Volume")
		ExpectEqual(properties.Looped, true, "Looped")
		ExpectEqual(properties.RollOffMode, Enum.RollOffMode.Linear, "RollOffMode")
		ExpectEqual(properties.LoopRegion, NumberRange.new(1.5, 2.5), "LoopRegion")
		ExpectEqual(full.EffectsCount, 1, "EffectsCount")

		local echo = (full.Effects :: any).EchoSoundEffect
		assert(echo, "The echo effect should round trip")
		ExpectEqual(echo.Name, "EchoSoundEffect", "Effect name")
		ExpectNear(echo.Delay, 0.75, "Effect delay")
		ExpectEqual(echo.Enabled, false, "Effect enabled")

		local bare, bareGroup = Codec.ReadDefinition(loaded, loaded.Offsets.Bare)
		ExpectEqual(bareGroup, 0, "No group")
		ExpectEqual((bare.Properties :: any).Name, "Bare", "Bare name")
		ExpectEqual(bare.EffectsCount, 0, "Bare effects")
	end)

	suite.Test("Codec handles an empty schema", function()
		local loaded = Codec.Load(Codec.Finish(Codec.NewWriter(), {}, {}))

		ExpectEqual(loaded.Count, 0, "Count")
		ExpectEqual(#loaded.GroupNames, 0, "Groups")
		ExpectEqual(#loaded.PreloadNames, 0, "Preloads")
	end)

	suite.Test("Codec rejects a buffer that is not a schema", function()
		ExpectError(function()
			Codec.Load(buffer.fromstring("not a schema"))
		end, "Load on garbage")
	end)

	suite.Test(`Codec grows past its first chunk with {LARGE_SCHEMA_SOUNDS} sounds`, function()
		local writer = Codec.NewWriter()
		local longId = "rbxassetid://" .. string.rep("9", 200)

		for index = 1, LARGE_SCHEMA_SOUNDS do
			Codec.WriteDefinition(writer, `Big{index}`, 1, {
				Properties = { Name = `Big{index}`, SoundId = longId, Volume = index / LARGE_SCHEMA_SOUNDS } :: any,
				Effects = {} :: any,
				EffectsCount = 0,
			})
		end

		local schemaBuffer = Codec.Finish(writer, { "BIG" }, {})
		Expect(buffer.len(schemaBuffer) > 64 * 1024, "The schema should be larger than the writer's first chunk")

		local loaded = Codec.Load(schemaBuffer)
		ExpectEqual(loaded.Count, LARGE_SCHEMA_SOUNDS, "Count")

		local last = Codec.ReadDefinition(loaded, loaded.Offsets[`Big{LARGE_SCHEMA_SOUNDS}`])
		ExpectEqual((last.Properties :: any).SoundId, longId, "Last SoundId")
		ExpectNear((last.Properties :: any).Volume, 1, "Last Volume")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--PROPERTIES--------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Properties never store deprecated, read-only or structural properties", function()
		local names = Properties.GetClassInfo("Sound").Names

		for _, forbidden in ipairs({
			"Pitch",
			"MaxDistance",
			"MinDistance",
			"EmitterSize",
			"IsPlaying",
			"TimeLength",
			"Parent",
			"Archivable",
			"ClassName",
		}) do
			Expect(not table.find(names, forbidden), `{forbidden} should not be a stored property`)
		end

		for _, required in ipairs({ "SoundId", "Volume", "PlaybackSpeed", "Looped", "RollOffMode", "SoundGroup" }) do
			Expect(table.find(names, required), `{required} should be a stored property`)
		end
	end)

	suite.Test("Properties read only what differs from the defaults", function()
		local sound = makeSound("Changed")
		sound.Volume = 0.3

		local read = Properties.ReadChanged(sound)
		ExpectNear(read.Volume, 0.3, "Volume")
		ExpectEqual(read.SoundId, "rbxasset://sounds/clickfast.wav", "SoundId")
		ExpectEqual(read.Looped, nil, "Looped is the default")
		ExpectEqual(read.PlaybackSpeed, nil, "PlaybackSpeed is the default")

		sound:Destroy()
	end)

	suite.Test("Properties apply what it can when a definition has bad keys (warnings expected)", function()
		local sound = Instance.new("Sound")

		local allApplied = Properties.Apply(sound, {
			Volume = 0.6,
			ClassName = "Part",
			Parent = workspace,
			NotARealProperty = 1,
			Looped = true,
		})

		ExpectEqual(allApplied, false, "Apply should report the bad key")
		ExpectNear(sound.Volume, 0.6, "Volume still applied")
		ExpectEqual(sound.Looped, true, "Looped still applied")
		ExpectEqual(sound.Parent, nil, "Parent is never applied")

		sound:Destroy()
	end)

	suite.Test("Converters build a hand-made definition without EffectsCount", function()
		local sound = Converters.DefinitionToSound({
			Properties = { Name = "HandMade", Volume = 0.1 } :: any,
			Effects = { ReverbSoundEffect = { WetLevel = 2 } } :: any,
		} :: any)

		ExpectEqual(sound.Name, "HandMade", "Name")
		local reverb = sound:FindFirstChild("ReverbSoundEffect")
		assert(reverb and reverb:IsA("ReverbSoundEffect"), "The effect should be built")
		ExpectNear(reverb.WetLevel, 2, "WetLevel")

		sound:Destroy()
	end)

	suite.Test("Converters skip an effect that is not a SoundEffect class (warnings expected)", function()
		local sound = Converters.DefinitionToSound({
			Properties = { Name = "Guarded" } :: any,
			Effects = { Part = { Anchored = true } } :: any,
			EffectsCount = 1,
		})

		ExpectEqual(#sound:GetChildren(), 0, "No child should be created")

		sound:Destroy()
	end)

	--------------------------------------------------------------------------------------------------------------------
	--COMPILE-----------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Compile finds sounds in any container and honors inherited preload tags", function()
		local root = Instance.new("Configuration")
		root.Name = "SOUNDS"

		local group = Instance.new("Configuration")
		group.Name = "GROUP"
		group.Parent = root

		local model = Instance.new("Model")
		model:AddTag("VluxySF_Preload")
		model.Parent = group
		makeSound("InModel").Parent = model

		local folder = Instance.new("Folder")
		folder.Parent = group
		makeSound("InFolder").Parent = folder

		local schemaBuffer, count = Compile.Build(root)
		ExpectEqual(count, 2, "Sound count")

		local loaded = Codec.Load(schemaBuffer)
		Expect(loaded.Offsets.InModel, "InModel should be compiled")
		Expect(loaded.Offsets.InFolder, "InFolder should be compiled")
		ExpectEqual(loaded.PreloadNames[1], "InModel", "InModel inherits the tag")
		ExpectEqual(#loaded.PreloadNames, 1, "InFolder is not tagged")

		root:Destroy()
	end)

	suite.Test("Compile rejects a non-Configuration under SOUNDS and duplicate group names", function()
		local root = Instance.new("Configuration")
		local folder = Instance.new("Folder")
		folder.Name = "NotAGroup"
		folder.Parent = root

		ExpectError(function()
			Compile.Build(root)
		end, "Folder under SOUNDS")
		root:Destroy()

		root = Instance.new("Configuration")
		for _ = 1, 2 do
			local group = Instance.new("Configuration")
			group.Name = "TWICE"
			group.Parent = root
		end

		ExpectError(function()
			Compile.Build(root)
		end, "Duplicate group")
		root:Destroy()
	end)

	suite.Test("Compile keeps the first of two sounds with the same name (warnings expected)", function()
		local root = Instance.new("Configuration")
		local group = Instance.new("Configuration")
		group.Name = "GROUP"
		group.Parent = root

		local first = makeSound("Twin")
		first.Volume = 0.1
		first.Parent = group

		local second = makeSound("Twin")
		second.Volume = 0.9
		second.Parent = group

		local schemaBuffer, count = Compile.Build(root)
		ExpectEqual(count, 1, "Sound count")

		local loaded = Codec.Load(schemaBuffer)
		local twin = Codec.ReadDefinition(loaded, loaded.Offsets.Twin)
		ExpectNear((twin.Properties :: any).Volume, 0.1, "The first Twin is kept")

		root:Destroy()
	end)
end

return InternalCases
