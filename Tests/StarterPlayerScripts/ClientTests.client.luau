--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InternalCases = require(ReplicatedStorage.InternalCases)
local SharedCases = require(ReplicatedStorage.SharedCases)
local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local Expect = TestHarness.Expect
local ExpectEqual = TestHarness.ExpectEqual
local ExpectError = TestHarness.ExpectError

local PRELOAD_TIMEOUT = 5

local suite = TestHarness.new("Client")

------------------------------------------------------------------------------------------------------------------------
--INIT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local connectedBeforeInit = false
VluxySF.Startup.ConnectForSchema(function()
	connectedBeforeInit = true
end)

suite.Test("The schema is not ready before InitClient", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), false, "IsInitialized")
end)

--Yields until the schema arrives and the tagged sounds are preloaded, or the timeout is reached.
local initStart = os.clock()
VluxySF.Startup.InitClient(PRELOAD_TIMEOUT)
local initSeconds = os.clock() - initStart

suite.Test("InitClient makes the schema ready", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), true, "IsInitialized")
	ExpectEqual(connectedBeforeInit, true, "ConnectForSchema callback ran")

	local timings = require(ReplicatedStorage.VluxySF.Core.SchemaStore).Timings
	local received = TestHarness.Milliseconds(timings.Receive)
	local loaded = TestHarness.Milliseconds(timings.Load)
	local preloaded = TestHarness.Milliseconds(timings.Preload)
	local total = TestHarness.Milliseconds(initSeconds)
	print(
		`[VluxySF Tests] InitClient took {total} ms for {#VluxySF.Schema.GetNames()} sounds (receive {received}, load {loaded}, preload {preloaded}).`
	)
end)

suite.Test("InitClient refuses to run twice", function()
	ExpectError(function()
		VluxySF.Startup.InitClient(0)
	end, "Second InitClient")
end)

SharedCases.Run(suite)
InternalCases.Run(suite)

------------------------------------------------------------------------------------------------------------------------
--PRELOAD---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local schema = VluxySF.Schema.Get()

suite.Test("InitClient waited for the preloads", function()
	ExpectEqual(VluxySF.Startup.IsPreloaded(), true, "IsPreloaded")

	--Returns right away when the preloads are done.
	VluxySF.Startup.WaitForPreload()
end)

suite.Test("Tagged sounds are preloaded by InitClient", function()
	local preloaded = VluxySF.Preload.Get()

	for _, name in ipairs({ "BattleOne", "BattleTwo", "Click" }) do
		Expect(preloaded[name], `{name} should be preloaded`)
		Expect(schema.PreloadedSounds:FindFirstChild(name), `{name} should be kept in PreloadedSounds`)
	end

	ExpectEqual(preloaded.MainTheme, nil, "MainTheme is not tagged")
end)

suite.Test("Fetching a preloaded sound gives a new clone", function()
	local sound: Sound = VluxySF.Fetch("Click")

	ExpectEqual(sound.Name, "Click", "Name")
	Expect(sound ~= VluxySF.Preload.Get().Click, "Fetch should not hand out the stored sound")
	Expect(not sound:IsDescendantOf(schema.PreloadedSounds), "The clone should not stay in PreloadedSounds")

	sound:Destroy()
end)

suite.Test("Preload.Selected preloads more sounds at runtime", function()
	VluxySF.Preload.Selected("Explosion")

	Expect(VluxySF.Preload.Get().Explosion, "Explosion should be preloaded")
end)

------------------------------------------------------------------------------------------------------------------------
--CACHE-----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

suite.Test("Cache warms and chills a sound", function()
	ExpectEqual(VluxySF.Cache.IsWarmed("MainTheme"), false, "IsWarmed before Warm")

	VluxySF.Cache.Warm("MainTheme")
	ExpectEqual(VluxySF.Cache.IsWarmed("MainTheme"), true, "IsWarmed after Warm")

	local warmed = VluxySF.Cache.Get().MainTheme
	assert(warmed, "MainTheme should be in the cache")
	ExpectEqual(warmed.Parent, schema.WarmedSounds, "Warmed sound parent")

	local sound: Sound = VluxySF.Fetch("MainTheme")
	Expect(sound ~= warmed, "Fetch should clone the warmed sound")
	sound:Destroy()

	VluxySF.Cache.Chill("MainTheme")
	ExpectEqual(VluxySF.Cache.IsWarmed("MainTheme"), false, "IsWarmed after Chill")
	ExpectEqual(warmed.Parent, nil, "Warmed sound parent after Chill")
end)

suite.Finish()

------------------------------------------------------------------------------------------------------------------------
--LISTENING_CHECK-------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--The cases above cannot hear anything, so play one sound for a person to check.
print("[VluxySF Tests] You should hear one click now.")
VluxySF.FetchPlayOnce("Click", nil, nil, true)

--With a stress group compiled, time the fetch path too. Run from here, not the command bar: the command bar has its
--own module cache in Studio, so its copy of the library never initializes.
if #VluxySF.Schema.GetNames() >= 1000 then
	require(ReplicatedStorage.FetchBenchmark).Run(3)
end
