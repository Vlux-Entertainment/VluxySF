--!strict

--[[
	Times the library's hot paths and prints one line per measurement.

	Numbers only, no pass or fail: timings depend on the machine. A line is printed as a warning and marked SLOW when
	it is far above what 2.x measured, as a hint to look closer, not as a failure.

	The test scripts run it on both sides whenever the schema has 1000 sounds or more (see StressFixture). Do not run
	it from the command bar: in Studio the command bar has its own module cache, so its copy of the library is never
	initialized and WaitUntilReady yields forever.
]]
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VluxySF = require(ReplicatedStorage.VluxySF)

local library = ReplicatedStorage.VluxySF
local Codec = require(library.Core.Codec)
local Compression = require(library.Core.Compression)
local Converters = require(library.Core.Converters)
local SchemaStore = require(library.Core.SchemaStore)
local Transport = require(library.Core.Transport)

--How many passes the Fetch timings average over.
local FETCH_PASSES = 3

--How many sounds the clone and OneShot timings use.
local SAMPLE_SIZE = 1000

--How many sounds the client tries to load, to check that the fixture's assets really play.
local PLAYABLE_SAMPLE = 100

--Seconds the asset check waits before reporting.
local PLAYABLE_TIMEOUT = 20

--Microseconds per item above which a line is marked SLOW. Several times the 2.0 measurements (Fetch was 11 to 13 us).
local BUDGETS = {
	Decode = 25,
	Build = 50,
	FirstFetch = 75,
	Fetch = 50,
	WrappedFetch = 55,
	Clone = 50,
	PlayOnce = 100,
}

local side = if RunService:IsServer() then "Server" else "Client"

local Benchmarks = {}

------------------------------------------------------------------------------------------------------------------------

local function line(message: string)
	print(`[VluxySF Bench] {side}: {message}`)
end

--[[
	Prints the total and the per-item time, as a warning when the per-item time is over its budget.
]]
local function report(label: string, seconds: number, count: number, budget: number?)
	local perItem = seconds / count * 1e6
	local message = string.format("%s: %.2f ms for %d (%.2f us each)", label, seconds * 1000, count, perItem)

	if budget and perItem > budget then
		warn(`[VluxySF Bench] {side}: {message}  SLOW, budget {budget} us`)
	else
		line(message)
	end
end

--Rounds a number the way a Sound property stores it, as a 32 bit float.
local f32Scratch = buffer.create(4)
local function asF32(value: number): number
	buffer.writef32(f32Scratch, 0, value)

	return buffer.readf32(f32Scratch, 0)
end

--[[
	Builds a schema shaped like a real game's, unlike the stress fixture whose sounds all share one SoundId: unique
	13 digit asset ids, a few float properties, a reverb on some sounds.
]]
local function buildRealisticSchema(count: number): buffer
	local random = Random.new(3)
	local writer = Codec.NewWriter()

	for index = 1, count do
		local name = `Sound_{index}`
		local properties: { [string]: any } = {
			Name = name,
			SoundId = `rbxassetid://{random:NextInteger(1000000000000, 9999999999999)}`,
			Volume = asF32(random:NextNumber(0.1, 1)),
			RollOffMaxDistance = asF32(random:NextInteger(40, 200)),
		}
		if index % 3 == 0 then
			properties.PlaybackSpeed = asF32(random:NextNumber(0.8, 1.2))
		end
		if index % 5 == 0 then
			properties.Looped = true
		end

		local effects: { [string]: { [string]: any } } = {}
		if index % 10 == 0 then
			effects.ReverbSoundEffect = { Name = "ReverbSoundEffect", DecayTime = asF32(random:NextNumber(0.5, 3)) }
		end

		Codec.WriteDefinition(writer, name, index % 6 + 1, {
			Properties = properties :: any,
			Effects = effects :: any,
			EffectsCount = if effects.ReverbSoundEffect then 1 else 0,
		})
	end

	return Codec.Finish(writer, { "A", "B", "C", "D", "E", "F" }, {})
end

local function reportSize(label: string, schemaBuffer: buffer, count: number)
	local clock = os.clock()
	local compressed = Compression.Compress(schemaBuffer)
	local compressSeconds = os.clock() - clock

	clock = os.clock()
	Compression.Decompress(compressed)
	local decompressSeconds = os.clock() - clock

	line(
		string.format(
			"%s: %.1f bytes per sound raw, %.1f compressed (%.0f%%); compress %.2f ms, decompress %.2f ms",
			label,
			buffer.len(schemaBuffer) / count,
			buffer.len(compressed) / count,
			buffer.len(compressed) / buffer.len(schemaBuffer) * 100,
			compressSeconds * 1000,
			decompressSeconds * 1000
		)
	)
end

local function destroyAll(sounds: { Instance })
	for _, sound in ipairs(sounds) do
		sound:Destroy()
	end
end

local function sample(names: { string }): { string }
	return table.move(names, 1, math.min(SAMPLE_SIZE, #names), 1, {})
end

------------------------------------------------------------------------------------------------------------------------

--[[
	@yields

	Runs every benchmark once and prints the results.
]]
function Benchmarks.Run()
	VluxySF.Startup.WaitUntilReady()

	local loaded = SchemaStore.GetLoaded()
	assert(loaded, "The schema should be loaded")

	local names = VluxySF.Schema.GetNames()
	local count = #names

	line(`{count} sounds, schema buffer {buffer.len(loaded.Buffer)} bytes.`)

	--CODEC--------------------------------------------------------------------------------------------------------------

	local clock = os.clock()
	local fresh = Codec.Load(loaded.Buffer)
	report("Codec.Load, the header and name index", os.clock() - clock, 1)

	local memoryBefore = gcinfo()
	local decoded: { any } = table.create(count)

	clock = os.clock()
	for index, name in ipairs(names) do
		decoded[index] = Codec.ReadDefinition(fresh, name)
	end
	report("Decode one definition", os.clock() - clock, count, BUDGETS.Decode)
	line(`decoding every definition holds about {gcinfo() - memoryBefore} KB of Lua memory.`)

	--BUILDING-----------------------------------------------------------------------------------------------------------

	local built: { Instance } = table.create(count)

	clock = os.clock()
	for index, definition in ipairs(decoded) do
		built[index] = Converters.DefinitionToSound(definition)
	end
	report("Build a Sound from a decoded definition", os.clock() - clock, count, BUDGETS.Build)
	destroyAll(built)
	table.clear(decoded)

	clock = os.clock()
	for index, name in ipairs(names) do
		built[index] = Converters.DefinitionToSound((Codec.ReadDefinition(fresh, name)) :: any)
	end
	report("First fetch of a name (decode + build)", os.clock() - clock, count, BUDGETS.FirstFetch)
	destroyAll(built)

	task.wait()

	--FETCHING-----------------------------------------------------------------------------------------------------------

	local fetchSeconds = 0
	for _ = 1, FETCH_PASSES do
		clock = os.clock()
		for index, name in ipairs(names) do
			built[index] = VluxySF.Fetch(name)
		end
		fetchSeconds += os.clock() - clock

		destroyAll(built)
		task.wait()
	end
	report(
		`Fetch, definition already decoded ({FETCH_PASSES} passes)`,
		fetchSeconds,
		count * FETCH_PASSES,
		BUDGETS.Fetch
	)

	local identity = VluxySF.WithWrapper(function(sound: Sound): Sound
		return sound
	end)

	clock = os.clock()
	for index, name in ipairs(names) do
		built[index] = identity.Fetch(name)
	end
	report("Fetch through WithWrapper", os.clock() - clock, count, BUDGETS.WrappedFetch)
	destroyAll(built)
	table.clear(built)

	task.wait()

	--TEMPLATES (client only: Cache needs the client)--------------------------------------------------------------------

	local sampled = sample(names)

	if side == "Client" then
		VluxySF.Cache.Warm(table.unpack(sampled))

		clock = os.clock()
		for index, name in ipairs(sampled) do
			built[index] = VluxySF.Fetch(name)
		end
		report("Fetch from a warmed template (clone)", os.clock() - clock, #sampled, BUDGETS.Clone)

		destroyAll(built)
		table.clear(built)
		VluxySF.Cache.Chill(table.unpack(sampled))

		task.wait()
	end

	--FETCH_PLAY_ONCE----------------------------------------------------------------------------------------------------

	local mute = VluxySF.Presets.Volume(0)
	local cleanups: { () -> () } = table.create(#sampled)

	clock = os.clock()
	for index, name in ipairs(sampled) do
		cleanups[index] = VluxySF.OneShot(name, nil, mute)
	end
	report("OneShot", os.clock() - clock, #sampled, BUDGETS.PlayOnce)

	for _, cleanup in ipairs(cleanups) do
		cleanup()
	end

	--SIZE_AND_COMPRESSION-----------------------------------------------------------------------------------------------

	reportSize("This schema", loaded.Buffer, count)
	reportSize("Realistic schema, same sound count", buildRealisticSchema(count), count)

	--PLAYABLE_ASSETS (client only)--------------------------------------------------------------------------------------

	if side == "Client" then
		local probes: { Instance } = {}
		local step = math.max(1, count // PLAYABLE_SAMPLE)
		for index = 1, count, step do
			table.insert(probes, VluxySF.Fetch(names[index]))
			if #probes == PLAYABLE_SAMPLE then
				break
			end
		end

		--PreloadAsync waits for every asset, and a slow one can take minutes, so it runs in its own thread and the
		--report goes out after PLAYABLE_TIMEOUT whatever is still pending
		local loadedCount, failed = 0, 0
		local finished = false
		clock = os.clock()

		task.spawn(function()
			ContentProvider:PreloadAsync(probes, function(_contentId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Success then
					loadedCount += 1
				else
					failed += 1
				end
			end)
			finished = true
		end)

		while not finished and os.clock() - clock < PLAYABLE_TIMEOUT do
			task.wait(0.1)
		end

		line(
			string.format(
				"assets that load: %d of %d sampled, %d failed, %d still loading after %.1f s",
				loadedCount,
				#probes,
				failed,
				#probes - loadedCount - failed,
				os.clock() - clock
			)
		)
		destroyAll(probes)
	end

	--TRANSPORT----------------------------------------------------------------------------------------------------------

	--the same steps Transport.Publish and Transport.Receive take
	clock = os.clock()
	local text = Transport.Encode(Compression.Compress(loaded.Buffer))
	report(`Publish: compress + base64 encode ({#text} characters)`, os.clock() - clock, 1)

	clock = os.clock()
	Compression.Decompress(Transport.Decode(text) :: buffer)
	report("Receive: base64 decode + decompress", os.clock() - clock, 1)
end

return Benchmarks
