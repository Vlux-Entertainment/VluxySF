--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedCases = require(ReplicatedStorage.SharedCases)
local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local Expect = TestHarness.Expect
local ExpectEqual = TestHarness.ExpectEqual

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
VluxySF.Startup.InitClient(PRELOAD_TIMEOUT)

suite.Test("InitClient makes the schema ready", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), true, "IsInitialized")
	ExpectEqual(connectedBeforeInit, true, "ConnectForSchema callback ran")
end)

SharedCases.Run(suite)

------------------------------------------------------------------------------------------------------------------------
--PRELOAD---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local schema = VluxySF.Schema.Get()

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
