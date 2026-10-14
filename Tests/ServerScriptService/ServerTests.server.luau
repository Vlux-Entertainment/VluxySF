--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local InternalCases = require(ReplicatedStorage.InternalCases)
local SharedCases = require(ReplicatedStorage.SharedCases)
local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local ExpectEqual = TestHarness.ExpectEqual

local suite = TestHarness.new("Server")

--The test place builds this from Tests/ServerStorage/TEST_SOUNDS.model.json
local soundConfig = ServerStorage:FindFirstChild("TEST_SOUNDS") :: Configuration

------------------------------------------------------------------------------------------------------------------------
--BEFORE_INIT-----------------------------------------------------------------------------------------------------------
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

--A game callback that errors must not stop InitServer or the other callbacks.
VluxySF.Startup.OnReady(function()
	error("[VluxySF Tests] Server: this error is expected, from an OnReady callback that errors on purpose.")
end)

suite.Test("Nothing throws before InitServer (warnings expected)", function()
	ExpectEqual(VluxySF.Startup.IsReady(), false, "IsReady")
	ExpectEqual(VluxySF.Startup.WaitUntilReady(0.05), false, "WaitUntilReady times out")
	ExpectEqual(connectedBeforeInit, false, "OnReady callback ran")

	local blank = VluxySF.Fetch("Click")
	ExpectEqual(blank.Name, "VluxySF_Blank_Sound", "Fetch gives a blank sound")
	ExpectEqual(blank.Parent, nil, "The early blank sound is unparented")
	blank:Destroy()

	ExpectEqual(VluxySF.TryFetch("Click"), nil, "TryFetch gives nil")
	VluxySF.OneShot("Click")()
	ExpectEqual(VluxySF.Schema.Get(), nil, "Schema.Get gives nil")
	ExpectEqual(VluxySF.Schema.Has("Click"), false, "Schema.Has gives false")
	ExpectEqual(#VluxySF.Groups.GetNames(), 0, "Groups.GetNames gives an empty list")
	VluxySF.Groups.SetVolume("MUSIC", 0.5)
end)

------------------------------------------------------------------------------------------------------------------------
--INIT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local initStart = os.clock()
VluxySF.Startup.InitServer(soundConfig)
local initSeconds = os.clock() - initStart

suite.Test("InitServer makes the library ready", function()
	ExpectEqual(VluxySF.Startup.IsReady(), true, "IsReady")
	ExpectEqual(VluxySF.Startup.WaitUntilReady(0), true, "WaitUntilReady")
	ExpectEqual(VluxySF.Startup.IsPreloaded(), true, "IsPreloaded on the server")
	ExpectEqual(VluxySF.Startup.WaitUntilPreloaded(1), true, "WaitUntilPreloaded on the server")
	ExpectEqual(connectedBeforeInit, true, "OnReady callback ran")
end)

suite.Test("InitServer detaches the sounds Configuration it was given", function()
	ExpectEqual(soundConfig.Parent, nil, "TEST_SOUNDS parent")
end)

suite.Test("A cancelled OnReady callback never runs", function()
	ExpectEqual(cancelledRan, false, "Cancelled callback ran")
end)

suite.Test("A OnReady callback that errors does not stop startup", function()
	ExpectEqual(VluxySF.Startup.IsReady(), true, "IsReady")
	ExpectEqual(connectedBeforeInit, true, "The other callback ran")
end)

suite.Test("A second InitServer is ignored (warnings expected)", function()
	local names = #VluxySF.Schema.GetNames()

	VluxySF.Startup.InitServer(Instance.new("Configuration"))
	ExpectEqual(#VluxySF.Schema.GetNames(), names, "Sound count after the second call")
end)

suite.Test("InitServer published the schema in SoundService", function()
	local published = game:GetService("SoundService"):FindFirstChild("VluxySF_Schema")
	assert(published, "VluxySF_Schema should exist in SoundService")

	local text = published:GetAttribute("Schema")
	ExpectEqual(type(text), "string", "Schema attribute type")
	local attributeCount = 0
	for _ in pairs(published:GetAttributes()) do
		attributeCount += 1
	end
	ExpectEqual(attributeCount, 1, "Attribute count")

	local soundCount = #VluxySF.Schema.GetNames()
	local timings = require(ReplicatedStorage.VluxySF.Core.SchemaStore).Timings
	print(
		`[VluxySF Tests] InitServer compiled {soundCount} sounds in {TestHarness.Milliseconds(initSeconds)} ms (compile {TestHarness.Milliseconds(
			timings.Compile
		)}, publish {TestHarness.Milliseconds(timings.Publish)}).`
	)
	print(`[VluxySF Tests] Schema is {#text} base64 characters in one attribute.`)
end)

InternalCases.Run(suite)

suite.Test("Preload and Cache do nothing on the server (warnings expected)", function()
	VluxySF.Preload.AddAsync("Click")
	ExpectEqual(VluxySF.Preload.Has("Click"), false, "Preload.Has")
	ExpectEqual(#VluxySF.Preload.GetNames(), 0, "Preload.GetNames")

	VluxySF.Cache.Warm("Click")
	ExpectEqual(VluxySF.Cache.IsWarmed("Click"), false, "Cache.IsWarmed")
end)

SharedCases.Run(suite)

suite.Finish()

--With a stress group compiled, time the fetch path too. Run from here, not the command bar: the command bar has its
--own module cache in Studio, so its copy of the library never initializes.
if #VluxySF.Schema.GetNames() >= 1000 then
	require(ReplicatedStorage.Benchmarks).Run()
end
