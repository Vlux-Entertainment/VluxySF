--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestHarness = require(ReplicatedStorage.TestHarness)

local library = ReplicatedStorage.VluxySF
local Codec = require(library.Core.Codec)
local Compile = require(library.Core.Compile)
local Compression = require(library.Core.Compression)
local Converters = require(library.Core.Converters)
local Owned = require(library.Utility.Owned)
local Properties = require(library.Core.Properties)
local Transport = require(library.Core.Transport)
local Types = require(library.Types)

local Expect = TestHarness.Expect
local ExpectContains = TestHarness.ExpectContains
local ExpectEqual = TestHarness.ExpectEqual
local ExpectError = TestHarness.ExpectError
local ExpectNear = TestHarness.ExpectNear

local LARGE_SCHEMA_SOUNDS = 2000

--The enum cache used to key on enum id * 65536 + item id, which collides once string ids pass this.
local ENUM_COLLISION_STRIDE = 65536

--[[
	Cases for the core modules that the public API does not reach directly: the codec, property reading, and the
	compile walk. They do not need the schema, so they run on both sides.
]]
local InternalCases = {}

------------------------------------------------------------------------------------------------------------------------

--Decodes a definition that the case expects to exist.
local function readDefinition(loaded: Codec.Loaded, name: string): (Types.SoundDefinition, number)
	local definition, groupIndex = Codec.ReadDefinition(loaded, name)
	assert(definition, `{name} should be in the schema`)

	return definition, groupIndex
end

--A schema with one sound, "Rolled", whose only stored property besides Name is the given RollOffMode.
local function loadRolled(rollOffMode: Enum.RollOffMode): Codec.Loaded
	local writer = Codec.NewWriter()

	Codec.WriteDefinition(writer, "Rolled", 0, {
		Properties = { Name = "Rolled", RollOffMode = rollOffMode } :: any,
		Effects = {} :: any,
		EffectsCount = 0,
	})

	return Codec.Load(Codec.Finish(writer, {}, {}))
end

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

		local full, fullGroup = readDefinition(loaded, "Full")
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

		local bare, bareGroup = readDefinition(loaded, "Bare")
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

		local last = readDefinition(loaded, `Big{LARGE_SCHEMA_SOUNDS}`)
		ExpectEqual((last.Properties :: any).SoundId, longId, "Last SoundId")
		ExpectNear((last.Properties :: any).Volume, 1, "Last Volume")
	end)

	suite.Test("Codec keeps enums apart between two loaded schemas", function()
		--Both buffers have the same string ids, so a cache shared between them would hand one the other's enum.
		local linear = loadRolled(Enum.RollOffMode.Linear)
		local inverse = loadRolled(Enum.RollOffMode.Inverse)

		local fromInverse = readDefinition(inverse, "Rolled")
		local fromLinear = readDefinition(linear, "Rolled")

		ExpectEqual((fromInverse.Properties :: any).RollOffMode, Enum.RollOffMode.Inverse, "Inverse schema")
		ExpectEqual((fromLinear.Properties :: any).RollOffMode, Enum.RollOffMode.Linear, "Linear schema")
	end)

	suite.Test(`Codec keeps enums apart when the string table passes {ENUM_COLLISION_STRIDE} entries`, function()
		--Two (enum, item) pairs whose old cache keys were equal: (e, i + 65536) and (e + 1, i). "Button" is both an
		--item of StudioStyleGuideColor and an enum name, so interning StudioStyleGuideColor.Button gives the two enum
		--names adjacent ids; "Jump" is interned early for the small item id, and fillers push the next new item name
		--exactly 65536 ids past it.
		local writer = Codec.NewWriter()

		local function write(name: string, properties: { [string]: any })
			Codec.WriteDefinition(
				writer,
				name,
				0,
				{ Properties = properties :: any, Effects = {} :: any, EffectsCount = 0 }
			)
		end

		write("Early", { Name = "Early", Action = Enum.PathWaypointAction.Jump })
		local jumpId = assert(table.find(writer.Strings, "Jump"), "Jump should be interned")

		write("Adjacent", { Name = "Adjacent", Color = Enum.StudioStyleGuideColor.Button })
		local colorId = assert(table.find(writer.Strings, "StudioStyleGuideColor"), "The enum name should be interned")
		ExpectEqual(table.find(writer.Strings, "Button"), colorId + 1, "Button follows StudioStyleGuideColor")

		--the Collide definition interns its name and its property name before the item name
		local targetId = jumpId + ENUM_COLLISION_STRIDE
		while #writer.Strings < targetId - 3 do
			local filler = `Filler{#writer.Strings}`
			write(filler, { Name = filler })
		end

		write("Collide", { Name = "Collide", Shade = Enum.StudioStyleGuideColor.MainBackground })
		ExpectEqual(table.find(writer.Strings, "MainBackground"), targetId, "MainBackground id")

		write("Jumped", { Name = "Jumped", Pressed = Enum.Button.Jump })

		local loaded = Codec.Load(Codec.Finish(writer, {}, {}))
		Expect(#loaded.Strings > ENUM_COLLISION_STRIDE, "The string table should be past the old key's range")

		--Collide is read first so its cached item would be handed to Jumped under a colliding key
		local collide = readDefinition(loaded, "Collide").Properties :: any
		ExpectEqual(collide.Shade, Enum.StudioStyleGuideColor.MainBackground, "Collide.Shade")

		local jumped = readDefinition(loaded, "Jumped").Properties :: any
		ExpectEqual(jumped.Pressed, Enum.Button.Jump, "Jumped.Pressed")

		local adjacent = readDefinition(loaded, "Adjacent").Properties :: any
		ExpectEqual(adjacent.Color, Enum.StudioStyleGuideColor.Button, "Adjacent.Color")
	end)

	suite.Test("Codec skips an enum that does not exist here (warnings expected)", function()
		local loaded = loadRolled(Enum.RollOffMode.Linear)

		--Stands in for an enum item that a newer engine had and this one does not.
		local index = table.find(loaded.Strings, "Linear")
		assert(index, "The string table should hold the enum item name")
		loaded.Strings[index] = "NotARealRollOffMode"

		local definition = readDefinition(loaded, "Rolled")
		ExpectEqual((definition.Properties :: any).RollOffMode, nil, "RollOffMode")
		ExpectEqual((definition.Properties :: any).Name, "Rolled", "The rest of the definition")
	end)

	suite.Test("Codec stores asset ids, numbers and booleans exactly", function()
		local properties = {
			Name = "Packed",
			SoundId = "rbxassetid://1234567890123",
			Volume = 0.5, --fits f32
			PlaybackSpeed = 0.1, --does not fit f32, so it must come back as the same double
			RollOffMaxDistance = 1e300, --far outside f32
			Looped = true,
			PlayOnRemove = false,
			LoopRegion = NumberRange.new(1.5, 2.5),
		}
		local stringsThatStayStrings = {
			"rbxasset://sounds/clickfast.wav", --not an rbxassetid
			"rbxassetid://0123", --leading zero would not survive as a number
			"rbxassetid://123456789012345678901234", --past 2^53
			"rbxassetid://", --no number
			"rbxassetid://12abc",
			"",
		}

		local writer = Codec.NewWriter()
		Codec.WriteDefinition(
			writer,
			"Packed",
			1,
			{ Properties = properties :: any, Effects = {} :: any, EffectsCount = 0 }
		)
		for index, value in ipairs(stringsThatStayStrings) do
			Codec.WriteDefinition(writer, `Text{index}`, 0, {
				Properties = { Name = `Text{index}`, SoundId = value } :: any,
				Effects = {} :: any,
				EffectsCount = 0,
			})
		end

		local loaded = Codec.Load(Codec.Finish(writer, { "SFX" }, {}))

		local packed = readDefinition(loaded, "Packed").Properties :: any
		for name, value in pairs(properties) do
			ExpectEqual(packed[name], value, name)
		end

		for index, value in ipairs(stringsThatStayStrings) do
			local text = readDefinition(loaded, `Text{index}`).Properties :: any
			ExpectEqual(text.SoundId, value, `String {index}`)
		end
	end)

	suite.Test("Codec stores names of any length and any UTF-8", function()
		local names = { string.rep("N", 300), "Звук_🔊_サウンド", "A" }

		local writer = Codec.NewWriter()
		for _, name in ipairs(names) do
			Codec.WriteDefinition(
				writer,
				name,
				300, --a group index past one varint byte
				{ Properties = { Name = name } :: any, Effects = {} :: any, EffectsCount = 0 }
			)
		end

		local loaded = Codec.Load(Codec.Finish(writer, {}, names))
		ExpectContains(loaded.Names, names, "Names")
		ExpectContains(loaded.PreloadNames, names, "Preload names")

		for _, name in ipairs(names) do
			local definition, groupIndex = readDefinition(loaded, name)
			ExpectEqual((definition.Properties :: any).Name, name, `Name of {#name} bytes`)
			ExpectEqual(groupIndex, 300, "Group index")
		end
	end)

	--------------------------------------------------------------------------------------------------------------------
	--COMPRESSION-------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Compression round trips every kind of input", function()
		local random = Random.new(2)

		local function randomBytes(length: number): buffer
			local bytes = buffer.create(length)
			for offset = 0, length - 1 do
				buffer.writeu8(bytes, offset, random:NextInteger(0, 255))
			end

			return bytes
		end

		local inputs: { [string]: buffer } = {
			Empty = buffer.create(0),
			["One byte"] = buffer.fromstring("x"),
			Short = buffer.fromstring("rbxassetid://"),
			["Random 100 KB"] = randomBytes(100000),
			["One byte repeated"] = buffer.fromstring(string.rep("a", 70000)),
			["Short pattern repeated"] = buffer.fromstring(string.rep("abc", 30000)),
			["Long match lengths"] = buffer.fromstring(string.rep("0123456789", 5000) .. "end"),
		}

		local mixed = buffer.create(60000)
		for offset = 0, 59999 do
			buffer.writeu8(mixed, offset, if offset % 7 == 0 then random:NextInteger(0, 255) else offset % 13)
		end
		inputs.Mixed = mixed

		for label, input in pairs(inputs) do
			local output = Compression.Decompress(Compression.Compress(input))
			ExpectEqual(buffer.tostring(output), buffer.tostring(input), label)
		end

		local repeated = Compression.Compress(inputs["Short pattern repeated"])
		Expect(buffer.len(repeated) < 1000, `Repeated data should shrink, got {buffer.len(repeated)} bytes`)
	end)

	suite.Test("Compression refuses damaged input", function()
		local compressed = Compression.Compress(buffer.fromstring(string.rep("abcdefgh", 1000)))

		local truncated = buffer.create(buffer.len(compressed) - 3)
		buffer.copy(truncated, 0, compressed, 0, buffer.len(truncated))
		ExpectError(function()
			Compression.Decompress(truncated)
		end, "Truncated input")

		local lying = buffer.create(buffer.len(compressed))
		buffer.copy(lying, 0, compressed)
		buffer.writeu32(lying, 0, 5) --claims a shorter original
		ExpectError(function()
			Compression.Decompress(lying)
		end, "Wrong length")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--TRANSPORT---------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Transport base64 round trips every padding case", function()
		ExpectEqual(Transport.Encode(buffer.fromstring("Man")), "TWFu", "3 bytes")
		ExpectEqual(Transport.Encode(buffer.fromstring("Ma")), "TWE=", "2 bytes")
		ExpectEqual(Transport.Encode(buffer.fromstring("M")), "TQ==", "1 byte")
		ExpectEqual(Transport.Encode(buffer.create(0)), "", "0 bytes")

		--random bytes, zeros included: a zero byte is what cuts raw strings short when they replicate
		local random = Random.new(1)

		for _, length in ipairs({ 0, 1, 2, 3, 4, 5, 255, 256, 257, 100000 }) do
			local source = buffer.create(length)
			for offset = 0, length - 1 do
				buffer.writeu8(source, offset, random:NextInteger(0, 255))
			end

			local decoded = Transport.Decode(Transport.Encode(source))
			assert(decoded, `{length} bytes should decode`)
			ExpectEqual(buffer.tostring(decoded), buffer.tostring(source), `{length} bytes`)
		end
	end)

	suite.Test("Transport refuses damaged base64", function()
		ExpectEqual(Transport.Decode("TWF"), nil, "Length that is not a multiple of 4")
		ExpectEqual(Transport.Decode("TW!u"), nil, "Character outside the alphabet")
		ExpectEqual(Transport.Decode("TQ==TWFu"), nil, "Padding in the middle")
		ExpectEqual(Transport.Decode("TW\0u"), nil, "A zero byte")
		ExpectEqual(Transport.Decode("\0\0\0\0"), nil, "Only zero bytes")
	end)

	--------------------------------------------------------------------------------------------------------------------
	--OWNED-------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------

	suite.Test("Owned finds only a marked child of the right class and gives up at the deadline", function()
		local parent = Instance.new("Folder")

		--the game's own instance with the library's name, and a marked one of the wrong class
		local decoy = Instance.new("Folder")
		decoy.Name = "Holder"
		decoy.Parent = parent

		local wrongClass = Instance.new("Configuration")
		wrongClass.Name = "Holder"
		Owned.Mark(wrongClass)
		wrongClass.Parent = parent

		ExpectEqual(Owned.WaitFor(parent, "Holder", "Folder", os.clock() - 1), nil, "A deadline that already passed")

		local start = os.clock()
		ExpectEqual(Owned.WaitFor(parent, "Holder", "Folder", os.clock() + 0.1), nil, "Unmarked or wrong class")
		Expect(os.clock() - start >= 0.05, "WaitFor should wait until the deadline")

		local real = Instance.new("Folder")
		real.Name = "Holder"
		Owned.Mark(real)
		task.delay(0.05, function()
			real.Parent = parent
		end)
		ExpectEqual(Owned.WaitFor(parent, "Holder", "Folder", os.clock() + 2), real, "A marked child added later")
		ExpectEqual(Owned.WaitFor(parent, "Holder", "Folder", os.clock()), real, "A marked child already there")

		parent:Destroy()
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
			"Playing",
			"TimePosition",
			"Parent",
			"Archivable",
			"ClassName",
		}) do
			Expect(not table.find(names, forbidden), `{forbidden} should not be a stored property`)
		end

		for _, required in ipairs({
			"SoundId",
			"Volume",
			"PlaybackSpeed",
			"Looped",
			"RollOffMode",
			"SoundGroup",
			"PlayOnRemove",
		}) do
			Expect(table.find(names, required), `{required} should be a stored property`)
		end
	end)

	suite.Test("Properties read only what differs from the defaults", function()
		local sound = makeSound("Changed")
		sound.Volume = 0.3
		sound.TimePosition = 1.5

		local read = Properties.ReadChanged(sound)
		ExpectNear(read.Volume, 0.3, "Volume")
		ExpectEqual(read.SoundId, "rbxasset://sounds/clickfast.wav", "SoundId")
		ExpectEqual(read.Looped, nil, "Looped is the default")
		ExpectEqual(read.PlaybackSpeed, nil, "PlaybackSpeed is the default")
		ExpectEqual(read.TimePosition, nil, "TimePosition is runtime state")

		sound:Destroy()
	end)

	suite.Test("Properties apply nothing from something that is not a table (warnings expected)", function()
		local sound = Instance.new("Sound")

		ExpectEqual(Properties.Apply(sound, nil :: any), false, "Apply(nil)")
		ExpectEqual(Properties.Apply(sound, "Volume" :: any), false, "Apply(string)")
		ExpectNear(sound.Volume, 0.5, "Volume is untouched")

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

	suite.Test("Compile skips a non-Configuration under SOUNDS and a duplicate group (warnings expected)", function()
		local root = Instance.new("Configuration")

		local folder = Instance.new("Folder")
		folder.Name = "NotAGroup"
		folder.Parent = root
		makeSound("InFolder").Parent = folder

		for index = 1, 2 do
			local group = Instance.new("Configuration")
			group.Name = "TWICE"
			group.Parent = root
			makeSound(`InTwice{index}`).Parent = group
		end

		local loaded = Codec.Load((Compile.Build(root)))
		root:Destroy()

		ExpectEqual(#loaded.GroupNames, 1, "Group count")
		ExpectEqual(loaded.GroupNames[1], "TWICE", "The first TWICE group is kept")
		ExpectEqual(loaded.Offsets.InTwice1 ~= nil, true, "Sound in the kept group")
		ExpectEqual(loaded.Offsets.InTwice2, nil, "Sound in the skipped duplicate group")
		ExpectEqual(loaded.Offsets.InFolder, nil, "Sound in the skipped Folder")
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
		local twin = readDefinition(loaded, "Twin")
		ExpectNear((twin.Properties :: any).Volume, 0.1, "The first Twin is kept")

		root:Destroy()
	end)
end

return InternalCases
