--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

VluxySF.Startup.InitServer(soundConfig)

suite.Test("InitServer makes the schema ready", function()
	ExpectEqual(VluxySF.Startup.IsInitialized(), true, "IsInitialized")
	ExpectEqual(connectedBeforeInit, true, "ConnectForSchema callback ran")
end)

suite.Test("InitServer destroys the sounds Configuration it was given", function()
	ExpectEqual(soundConfig.Parent, nil, "TEST_SOUNDS parent")
end)

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
