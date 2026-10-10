--!strict
--!optimize 2

local RunService = game:GetService("RunService")

local Compile = require(script.Parent.Parent.Core.Compile)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Preloading = require(script.Parent.Parent.Core.Preloading)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Transport = require(script.Parent.Parent.Core.Transport)

local DEFAULT_PRELOAD_TIMEOUT = 5

--set as soon as an Init call starts, so a second call during the first one's yields is refused
local starting = false

--[=[
	@class Startup

	Starts the library and tells you when it is ready.

	The server compiles the `SOUNDS` Configuration into the schema once. Every client receives that schema when it
	joins. Until a side has started, most of the library errors when used, so other scripts should wait with
	`WaitForSchema` or `ConnectForSchema`.
]=]
local Startup = {}

------------------------------------------------------------------------------------------------------------------------

--[[
	@yields

	Waits until the startup preloads finish or the timeout passes. Warns when it timed out.
]]
local function waitForPreloads(timeout: number)
	if SchemaStore.IsPreloaded() then
		return
	end

	local thread = coroutine.running()
	local finished = false

	local function finish(timedOut: boolean)
		if finished then
			return
		end
		finished = true

		task.spawn(thread, timedOut)
	end

	local disconnect = SchemaStore.Preloaded:Once(function()
		finish(false)
	end)
	local timer = task.delay(timeout, finish, true)

	local timedOut = coroutine.yield()

	disconnect()
	if coroutine.status(timer) == "suspended" then
		task.cancel(timer)
	end

	if timedOut then
		FormatMessage.Warn(`Preloading did not finish within {timeout} seconds. Continuing without waiting.`)
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Startup

	@server

	Compiles the `SOUNDS` Configuration into the schema, publishes it to clients, and destroys the Configuration.

	:::danger
	Call this once. The schema is locked after it is built, so sounds and SoundGroups cannot be added while the game
	runs.
	:::

	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")

	local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

	VluxySF.Startup.InitServer(ServerStorage.SOUNDS)
	```

	@param soundFolder Configuration -- The `SOUNDS` Configuration.
]=]
function Startup.InitServer(soundFolder: Configuration)
	if not RunService:IsServer() then
		FormatMessage.Error("Startup.InitServer only works on the server!", 3)
	end
	if starting or SchemaStore.IsInitialized() then
		FormatMessage.Error("Startup.InitServer was already called!", 3)
	end
	if typeof(soundFolder) ~= "Instance" then
		FormatMessage.Error(`Startup.InitServer needs the SOUNDS Configuration, got {typeof(soundFolder)}.`, 3)
	end
	starting = true

	local timings = SchemaStore.Timings
	local clock = os.clock()

	local schemaBuffer, soundCount = Compile.Build(soundFolder)
	timings.Compile = os.clock() - clock
	if soundCount == 0 then
		FormatMessage.Warn(`{soundFolder.Name} has no Sounds in it. The schema is empty.`)
	end

	--detach now so nothing else reads it, destroy later so startup does not pay for tearing down the tree
	soundFolder.Parent = nil
	task.defer(function()
		soundFolder:Destroy()
	end)

	clock = os.clock()
	SchemaStore.LoadServer(schemaBuffer)
	Transport.Publish(schemaBuffer)
	timings.Publish = os.clock() - clock

	SchemaStore.SetInitialized()
end

--[=[
	@within Startup

	@client

	@yields

	Receives the schema from the server, then builds and preloads every sound tagged for preloading.

	The schema is ready as soon as it is received, so `WaitForSchema` and `ConnectForSchema` in other scripts resume
	then. This call itself yields until the preloads finish or `timeout` seconds pass, whichever comes first, and
	warns if it timed out. Pass `0` to not wait at all: the preloads still run in the background, no warning is
	printed, and you can check on them with `IsPreloaded` or `WaitForPreload`.

	:::danger
	Call this once per client.
	:::

	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

	VluxySF.Startup.InitClient(4)
	```

	@param timeout number? -- How long to wait for the preloads, in seconds. Default is 5. `0` does not wait.
]=]
function Startup.InitClient(timeout: number?)
	if not RunService:IsClient() then
		FormatMessage.Error("Startup.InitClient only works on the client!", 3)
	end
	if starting or SchemaStore.IsInitialized() then
		FormatMessage.Error("Startup.InitClient was already called!", 3)
	end

	local realTimeout = timeout or DEFAULT_PRELOAD_TIMEOUT
	if realTimeout < 0 then
		FormatMessage.Error(`Startup.InitClient timeout must be 0 or more, got {realTimeout}.`, 3)
	end
	starting = true

	local timings = SchemaStore.Timings
	local clock = os.clock()

	local schemaBuffer = Transport.Receive()
	timings.Receive = os.clock() - clock

	clock = os.clock()
	SchemaStore.LoadClient(schemaBuffer)

	--templates exist right away, so a Fetch can clone them even while the assets are still downloading
	local sounds = Preloading.Register(SchemaStore.GetPreloadNames(), false)
	timings.Load = os.clock() - clock

	--the schema is complete here; only the caller of InitClient waits for the preloads below
	SchemaStore.SetInitialized()

	if #sounds == 0 then
		timings.Preload = 0
		SchemaStore.SetPreloaded()

		return
	end

	clock = os.clock()
	task.spawn(function()
		Preloading.Load(sounds)
		timings.Preload = os.clock() - clock
		SchemaStore.SetPreloaded()
	end)

	if realTimeout > 0 then
		waitForPreloads(realTimeout)
	end
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Startup

	```lua
	print(VluxySF.Startup.IsInitialized())
	```

	@return boolean -- Whether the schema is ready on this side.
]=]
function Startup.IsInitialized(): boolean
	return SchemaStore.IsInitialized()
end

--[=[
	@within Startup

	@yields

	Yields until the schema is ready. Returns right away if it already is.

	```lua
	VluxySF.Startup.WaitForSchema()

	VluxySF.FetchPlayOnce("MySound")
	```
]=]
function Startup.WaitForSchema()
	if SchemaStore.IsInitialized() then
		return
	end

	SchemaStore.Initialized:Wait()
end

--[=[
	@within Startup

	Runs the callback once the schema is ready, without yielding. If it already is, the callback runs in a new thread
	right away.

	```lua
	VluxySF.Startup.ConnectForSchema(function()
		VluxySF.FetchPlayOnce("MySound")
	end)

	-- This line does not wait.
	```

	@param finished () -> () -- Runs when the schema is ready.

	@return () -> () -- Cancels the callback if it has not run yet.
]=]
function Startup.ConnectForSchema(finished: () -> ()): () -> ()
	if SchemaStore.IsInitialized() then
		local thread = task.spawn(finished)

		return function()
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end
	end

	return SchemaStore.Initialized:Once(finished)
end

--[=[
	@within Startup

	@client

	```lua
	print(VluxySF.Startup.IsPreloaded())
	```

	@return boolean -- Whether the sounds tagged for preloading have finished loading.
]=]
function Startup.IsPreloaded(): boolean
	return SchemaStore.IsPreloaded()
end

--[=[
	@within Startup

	@client

	@yields

	Yields until the sounds tagged for preloading have finished loading. Returns right away if they have.
	Useful after `InitClient(0)`.

	```lua
	VluxySF.Startup.InitClient(0)

	-- Do other startup work here.

	VluxySF.Startup.WaitForPreload()
	```
]=]
function Startup.WaitForPreload()
	if SchemaStore.IsPreloaded() then
		return
	end

	SchemaStore.Preloaded:Wait()
end

return Startup
