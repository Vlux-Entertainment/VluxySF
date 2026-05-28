--!strict
--!optimize 2

local library = script.Parent.Parent

local internals = library.Internals
local utility = library.Utility

local Tables = require(utility.Tables)

local Types = require(library.Types)

------------------------------------------------------------------------------------------------------------

local initializedEvent = Instance.new("BindableEvent")
initializedEvent.Name = "Initialized"
initializedEvent.Parent = script

local isInitialized = false

local soundSchema: Types.SoundSchema = nil

local subStartup: (Types.SoundSchema) -> () = nil

------------------------------------------------------------------------------------------------------------

--[[
    Internals for this library.
]]
local Core = {}

--[[
	@param func (SoundSchema) -> () -- The function to be injected as the schema fail check.

	Injects a function to be used as a check for when the schhema exists.
]]
function Core._injectSubModules(schema: (Types.SoundSchema) -> ())
	subStartup = schema
end

------------------------------------------------------------------------------------------------------------

--[=[
	@class Startup

	Functions for checking the initialization status of the sound schema and waiting for it to be ready.
]=]
local Startup = {}

--[=[
	@within Startup

	@server

	@param soundFolder Configuration | Folder -- Folder containing all sound data

	Injects the source folder used to build sound data and sets up server-side structures.

	This should only run once!
]=]
function Startup.InitServer(soundFolder: Configuration | Folder)
	local Server = require(internals.Server)
	Server._initServer(soundFolder)

	--fetch
	soundSchema = Server.GetSoundSchema()
	Tables.DeepFreeze(soundSchema)

	subStartup(soundSchema)

	isInitialized = true
	initializedEvent:Fire()
end

--[=[
	@within Startup

	@client

	@yields

	@param timeout number? -- optional timeout for preloading sounds, default is 5 seconds

	Sets up client-side structures and retrieves sound data from the server.

	This should only run once!
]=]
function Startup.InitClient(timeout: number?)
	local Client = require(internals.Client)
	Client._initClient(timeout)

	--fetch
	soundSchema = Client.GetSoundSchema()
	Tables.DeepFreeze(soundSchema)

	subStartup(soundSchema)

	isInitialized = true
	initializedEvent:Fire()
end

------------------------------------------------------------------------------------------------------------

--[=[
	@within Startup

	@return boolean -- Whether the sound schema has been initialized.

	Checks if the sound schema has been initialized.
]=]
function Startup.IsInitialized(): boolean
	return isInitialized
end

--[=[ 
	@within Startup

	@yields

	@return boolean -- Whether the sound schema is ready for use.

	Waits until the sound schema is initialized and ready for use.

	If you know that your code will execute after the schema is loaded then this is not needed.
]=]
function Startup.WaitForSchema()
	if isInitialized then
		return
	end

	initializedEvent.Event:Wait()
end

Core.Startup = Startup

return Core
