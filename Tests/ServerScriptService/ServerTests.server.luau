--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local InternalCases = require(ReplicatedStorage.InternalCases)
local SharedCases = require(ReplicatedStorage.SharedCases)
local TestHarness = require(ReplicatedStorage.TestHarness)
local VluxySF = require(ReplicatedStorage.VluxySF)

local ExpectEqual = TestHarness.ExpectEqual
local ExpectError = TestHarness.ExpectError

local suite = TestHarness.new("Server")

--The test place builds this from Tests/ServerStorage/TEST_SOUNDS.model.json
local soundConfig = ServerStorage:FindFirstChild("TEST_SOUNDS") :: Configuration

------------------------------------------------------------------------------------------------------------------------
--BEFORE_INIT-----------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local connectedBeforeInit = false
VluxySF.Startup.ConnectForSchema(function()
	connectedBeforeInit = true
end)

local cancelledRan = false
local cancelConnection = VluxySF.Startup.ConnectForSchema(function()
	cancelledRan = true
end)
cancelConnection()

--A game callback that errors must not stop InitServer or the other callbacks.
VluxySF.Startup.ConnectForSchema(function()
	error("[VluxySF Tests] Server: this error is expected, from a ConnectForSchema callback that errors on purpose.")
end)

suite.Test("The schema is not ready before InitServer", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), false, "IsInitialized")
	ExpectEqual(connectedBeforeInit, false, "ConnectForSchema callback ran")

	ExpectError(function()
		VluxySF.Fetch("Click")
	end, "Fetch before init")
	ExpectError(function()
		VluxySF.Schema.Get()
	end, "Schema.Get before init")
end)

------------------------------------------------------------------------------------------------------------------------
--INIT------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local initStart = os.clock()
VluxySF.Startup.InitServer(soundConfig)
local initSeconds = os.clock() - initStart

suite.Test("InitServer makes the schema ready", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), true, "IsInitialized")
	ExpectEqual(connectedBeforeInit, true, "ConnectForSchema callback ran")
end)

suite.Test("InitServer detaches the sounds Configuration it was given", function()
	ExpectEqual(soundConfig.Parent, nil, "TEST_SOUNDS parent")
end)

suite.Test("A cancelled ConnectForSchema callback never runs", function()
	ExpectEqual(cancelledRan, false, "Cancelled callback ran")
end)

suite.Test("A ConnectForSchema callback that errors does not stop startup", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), true, "IsInitialized")
	ExpectEqual(connectedBeforeInit, true, "The other callback ran")
end)

suite.Test("InitServer refuses to run twice", function()
	ExpectError(function()
		VluxySF.Startup.InitServer(Instance.new("Configuration"))
	end, "Second InitServer")
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

suite.Test("Preload and Cache throw on the server", function()
	ExpectError(function()
		VluxySF.Preload.Get()
	end, "Preload.Get")
	ExpectError(function()
		VluxySF.Cache.Warm("Click")
	end, "Cache.Warm")
end)

SharedCases.Run(suite)

suite.Finish()

--With a stress group compiled, time the fetch path too. Run from here, not the command bar: the command bar has its
--own module cache in Studio, so its copy of the library never initializes.
if #VluxySF.Schema.GetNames() >= 1000 then
	require(ReplicatedStorage.Benchmarks).Run()
end
