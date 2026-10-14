--!strict

local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Codec = require(ReplicatedStorage.VluxySF.Core.Codec)
local Compression = require(ReplicatedStorage.VluxySF.Core.Compression)
local InternalCases = require(ReplicatedStorage.InternalCases)
local SharedCases = require(ReplicatedStorage.SharedCases)
local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local Expect = TestHarness.Expect
local ExpectContains = TestHarness.ExpectContains
local ExpectEqual = TestHarness.ExpectEqual

local PRELOAD_TIMEOUT = 5

--OneShot gives an asset this long to load before destroying the sound, plus a margin.
local PLAY_ONCE_WATCHDOG_SECONDS = 11

--How many times one player may ask the server for the schema through the fallback RemoteFunction.
local SCHEMA_REQUEST_LIMIT = 3

local suite = TestHarness.new("Client")

--Finds the instance the server made, by its mark, ignoring anything else with the same name.
local function findOwned(parent: Instance, name: string): Instance?
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name and child:GetAttribute("VluxySF") == true then
			return child
		end
	end

	return nil
end

------------------------------------------------------------------------------------------------------------------------
--DECOYS----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--Unmarked instances with the library's names, as a game migrating from its own SoundGroups might have in SoundService.
--They are made before InitClient so the client has to tell the server's instances from them by their mark.
local decoys: { Instance } = {}
for _, spec in ipairs({
	{ "VluxySF_Schema", "Configuration" },
	{ "SOUNDS", "SoundGroup" },
	{ "UnattachedSounds", "Configuration" },
}) do
	local decoy = Instance.new(spec[2])
	decoy.Name = spec[1]
	decoy.Parent = SoundService
	table.insert(decoys, decoy)
end

------------------------------------------------------------------------------------------------------------------------
--INIT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local connectedBeforeInit = false
VluxySF.Startup.OnReady(function()
	connectedBeforeInit = true
end)

local cancelledRan = false
local cancelConnection = VluxySF.Startup.OnReady(function()
	cancelledRan = true
end)
cancelConnection()

--A game callback that errors must not stop InitClient or the other callbacks.
VluxySF.Startup.OnReady(function()
	error("[VluxySF Tests] Client: this error is expected, from a OnReady callback that errors on purpose.")
end)

suite.Test("The schema is not ready before InitClient", function()
	ExpectEqual(VluxySF.Startup.IsReady(), false, "IsReady")
end)

--Yields until the schema arrives and the tagged sounds are preloaded, or the timeout is reached.
local memoryBefore = gcinfo()
local initStart = os.clock()
VluxySF.Startup.InitClient(PRELOAD_TIMEOUT)
local initSeconds = os.clock() - initStart
local memoryAfter = gcinfo()

--Started now and checked at the end, so the wait overlaps the other cases. A muted Click plays and ends normally at
--the same time: only the unloadable sound may produce a "did not load" warning.
local loadWarnings = 0
local logConnection = LogService.MessageOut:Connect(function(message: string)
	if string.find(message, "did not load within", 1, true) then
		loadWarnings += 1
	end
end)

VluxySF.OneShot("Click", nil, VluxySF.Presets.Volume(0))

--A one-shot whose parent the game destroys right away goes with it; that must not count as "did not load" either.
local doomed = Instance.new("Folder")
doomed.Parent = workspace
VluxySF.OneShot("Click", doomed, VluxySF.Presets.Volume(0))
doomed:Destroy()

local unloadable: Sound? = nil
local unloadableStart = os.clock()
print(
	`[VluxySF Tests] Client: a warning that "Click" did not load is expected about {PLAY_ONCE_WATCHDOG_SECONDS - 1} seconds from now.`
)
VluxySF.OneShot("Click", nil, function(sound: Sound)
	sound.SoundId = "rbxassetid://1" --not an audio asset, so it never loads
	sound.Volume = 0
	unloadable = sound
end)

suite.Test("InitClient makes the schema ready", function()
	ExpectEqual(VluxySF.Startup.IsReady(), true, "IsReady")
	ExpectEqual(connectedBeforeInit, true, "OnReady callback ran")

	local timings = require(ReplicatedStorage.VluxySF.Core.SchemaStore).Timings
	local received = TestHarness.Milliseconds(timings.Receive)
	local loaded = TestHarness.Milliseconds(timings.Load)
	local preloaded = TestHarness.Milliseconds(timings.Preload)
	local total = TestHarness.Milliseconds(initSeconds)
	print(
		`[VluxySF Tests] InitClient took {total} ms for {#VluxySF.Schema.GetNames()} sounds (receive {received}, load {loaded}, preload {preloaded}).`
	)
	print(`[VluxySF Tests] Lua memory grew about {memoryAfter - memoryBefore} KB during InitClient.`)
end)

suite.Test("InitClient found the server's instances by their mark, not the same-named decoys", function()
	local schema = assert(VluxySF.Schema.Get(), "The schema should be ready")

	for _, decoy in ipairs(decoys) do
		Expect(schema.SoundGroupContainer ~= decoy, "The SOUNDS decoy was skipped")
		Expect(schema.UnattachedSounds ~= decoy, "The UnattachedSounds decoy was skipped")
		decoy:Destroy()
	end

	ExpectEqual(schema.SoundGroupContainer:GetAttribute("VluxySF"), true, "SOUNDS is the marked one")
	ExpectEqual(schema.UnattachedSounds:GetAttribute("VluxySF"), true, "UnattachedSounds is the marked one")
	ExpectEqual((VluxySF.Groups.Get("MUSIC") :: SoundGroup):GetAttribute("VluxySF"), true, "MUSIC is marked")
end)

suite.Test("InitClient leaves the schema attribute in place for other readers", function()
	local published = findOwned(SoundService, "VluxySF_Schema")
	assert(published, "The marked VluxySF_Schema should have replicated")

	ExpectEqual(type(published:GetAttribute("Schema")), "string", "Schema attribute")
end)

suite.Test("The schema request fallback hands out the schema a few times per player", function()
	local published = assert(findOwned(SoundService, "VluxySF_Schema"), "VluxySF_Schema should have replicated")
	local request = published:WaitForChild("Request", 5)
	assert(request and request:IsA("RemoteFunction"), "A Request RemoteFunction should sit under the container")

	--InitClient may already have used one request when the attribute could not be read, so only the first and the
	--one past the limit are fixed
	local results: { any } = {}
	for index = 1, SCHEMA_REQUEST_LIMIT + 1 do
		results[index] = request:InvokeServer()
	end

	ExpectEqual(type(results[1]), "buffer", "The first request gets the schema")

	--the remote sends the compressed schema, the same bytes the attribute carries
	local schemaBuffer = Compression.Decompress(results[1])
	ExpectEqual(Codec.Load(schemaBuffer).Count, #VluxySF.Schema.GetNames(), "Sounds in the requested schema")
	ExpectEqual(results[SCHEMA_REQUEST_LIMIT + 1], nil, "A request past the limit gets nothing")
end)

suite.Test("A cancelled OnReady callback never runs", function()
	ExpectEqual(cancelledRan, false, "Cancelled callback ran")
end)

suite.Test("An OnReady callback that errors does not stop startup", function()
	ExpectEqual(VluxySF.Startup.IsReady(), true, "IsReady")
	ExpectEqual(connectedBeforeInit, true, "The other callback ran")
end)

suite.Test("A second InitClient is ignored (warnings expected)", function()
	VluxySF.Startup.InitClient(0)
	ExpectEqual(VluxySF.Startup.IsReady(), true, "IsReady after the second call")
end)

SharedCases.Run(suite)
InternalCases.Run(suite)

------------------------------------------------------------------------------------------------------------------------
--PRELOAD---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local schema = assert(VluxySF.Schema.Get(), "The schema should be ready")

suite.Test("InitClient waited for the preloads", function()
	ExpectEqual(VluxySF.Startup.IsPreloaded(), true, "IsPreloaded")

	--Returns right away when the preloads are done.
	VluxySF.Startup.WaitUntilPreloaded()
end)

suite.Test("Tagged sounds are preloaded by InitClient", function()
	for _, name in ipairs({ "BattleOne", "BattleTwo", "Click" }) do
		Expect(VluxySF.Preload.Has(name), `{name} should be preloaded`)
		Expect(schema.PreloadedSounds:FindFirstChild(name), `{name} should be kept in PreloadedSounds`)
	end

	ExpectEqual(VluxySF.Preload.Has("MainTheme"), false, "MainTheme is not tagged")
	ExpectContains(VluxySF.Preload.GetNames(), { "BattleOne", "BattleTwo", "Click" }, "Preload.GetNames")
end)

suite.Test("Preloaded templates are silent", function()
	for _, name in ipairs({ "BattleOne", "BattleTwo", "Click" }) do
		local kept = schema.PreloadedSounds:FindFirstChild(name)
		assert(kept and kept:IsA("Sound"), `{name} should be kept in PreloadedSounds`)

		ExpectEqual(kept.Playing, false, `{name} template is not playing`)
		ExpectEqual(kept.PlayOnRemove, false, `{name} template has PlayOnRemove off`)
	end
end)

suite.Test("Fetching a preloaded sound builds a new one", function()
	local kept = schema.PreloadedSounds:FindFirstChild("Click")
	local sound: Sound = VluxySF.Fetch("Click")

	ExpectEqual(sound.Name, "Click", "Name")
	Expect(sound ~= kept, "Fetch should not hand out the kept sound")
	Expect(not sound:IsDescendantOf(schema.PreloadedSounds), "The fetched sound should not stay in PreloadedSounds")

	sound:Destroy()
end)

suite.Test("Preload.AddAsync preloads more sounds at runtime", function()
	VluxySF.Preload.AddAsync("Explosion")

	Expect(VluxySF.Preload.Has("Explosion"), "Explosion should be preloaded")
end)

------------------------------------------------------------------------------------------------------------------------
--CACHE-----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

suite.Test("Cache warms and chills a sound", function()
	ExpectEqual(VluxySF.Cache.IsWarmed("MainTheme"), false, "IsWarmed before Warm")

	VluxySF.Cache.Warm("MainTheme")
	ExpectEqual(VluxySF.Cache.IsWarmed("MainTheme"), true, "IsWarmed after Warm")

	ExpectContains(VluxySF.Cache.GetNames(), { "MainTheme" }, "Cache.GetNames")

	local warmed = schema.WarmedSounds:FindFirstChild("MainTheme")
	assert(warmed, "MainTheme should be kept in WarmedSounds")
	ExpectEqual(warmed.Parent, schema.WarmedSounds, "Warmed sound parent")

	local sound: Sound = VluxySF.Fetch("MainTheme")
	Expect(sound ~= warmed, "Fetch should clone the warmed sound")
	sound:Destroy()

	VluxySF.Cache.Chill("MainTheme")
	ExpectEqual(VluxySF.Cache.IsWarmed("MainTheme"), false, "IsWarmed after Chill")
	ExpectEqual(warmed.Parent, nil, "Warmed sound parent after Chill")
end)

suite.Test("Warmed templates are silent and clones get PlayOnRemove back", function()
	--Whoosh is authored with PlayOnRemove on, so its template must have it off or chilling it would make a sound
	VluxySF.Cache.Warm("Whoosh")

	local warmed = schema.WarmedSounds:FindFirstChild("Whoosh")
	assert(warmed and warmed:IsA("Sound"), "Whoosh should be kept in WarmedSounds")
	ExpectEqual(warmed.Playing, false, "Template is not playing")
	ExpectEqual(warmed.PlayOnRemove, false, "Template has PlayOnRemove off")

	local sound: Sound = VluxySF.Fetch("Whoosh")
	ExpectEqual(sound.PlayOnRemove, true, "The clone gets the authored PlayOnRemove back")
	ExpectEqual(sound.Playing, false, "The clone is not playing")
	sound:Destroy()

	VluxySF.Cache.Chill("Whoosh")
	ExpectEqual(VluxySF.Cache.IsWarmed("Whoosh"), false, "IsWarmed after Chill")
end)

------------------------------------------------------------------------------------------------------------------------
--PLAY_ONCE_WATCHDOG----------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local remaining = PLAY_ONCE_WATCHDOG_SECONDS - (os.clock() - unloadableStart)
if remaining > 0 then
	task.wait(remaining)
end

suite.Test("OneShot destroys a sound whose asset never loads", function()
	local sound = unloadable
	assert(sound, "The preset should have received the sound")

	ExpectEqual(sound.Parent, nil, "Parent after the load timeout")
end)

suite.Test("OneShot does not flag a sound that loaded and ended, or one destroyed with its parent", function()
	ExpectEqual(loadWarnings, 1, '"did not load" warnings (only the unloadable sound should warn)')
end)

logConnection:Disconnect()

suite.Finish()

------------------------------------------------------------------------------------------------------------------------
--LISTENING_CHECK-------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--The cases above cannot hear anything, so play one sound for a person to check.
print("[VluxySF Tests] You should hear one click now.")
VluxySF.OneShot("Click")

--With a stress group compiled, time the fetch path too. Run from here, not the command bar: the command bar has its
--own module cache in Studio, so its copy of the library never initializes.
if #VluxySF.Schema.GetNames() >= 1000 then
	require(ReplicatedStorage.Benchmarks).Run()
end
