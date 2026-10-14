--!strict
--!optimize 2

local RunService = game:GetService("RunService")

local Compile = require(script.Parent.Parent.Core.Compile)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Preloading = require(script.Parent.Parent.Core.Preloading)
local SchemaStore = require(script.Parent.Parent.Core.SchemaStore)
local Transport = require(script.Parent.Parent.Core.Transport)

local DEFAULT_PRELOAD_TIMEOUT = 5

--how long a client waits for the server's schema and instances, separate from the preload timeout
local SCHEMA_TIMEOUT = 30

--set as soon as an Init call starts, so a second call during the first one's yields is refused
local starting = false
--set when an Init call gave up, so a later call explains that instead of claiming the first one is still running
local failed = false

--[=[
	@class Startup

	Starts the library and tells you when it is ready.

	The server compiles the `SOUNDS` Configuration into the schema once. Every client receives that schema when it
	joins. Until a side has started, the rest of the library warns once per function and returns blank sounds, `nil`
	or empty results, so other scripts should wait with `WaitUntilReady` or `OnReady`.

	Nothing here throws into your game code: calling an `Init` function twice, on the wrong side or with a bad
	argument prints a warning, and a failure while starting turns sounds off with a warning. A client gives up on
	the schema after 30 seconds, so a server that could not start never holds a client's script forever.
]=]
local Startup = {}

local startServer: (soundFolder: Configuration) -> ()
local startClient: () -> ()

------------------------------------------------------------------------------------------------------------------------

--[[
	Returns the timeout when it is usable. A timeout that is not a number of 0 or more warns and becomes nil, which
	waits without a limit, so a bad argument never throws.
]]
local function checkTimeout(timeout: any, functionName: string): number?
	if timeout == nil then
		return nil
	end

	if type(timeout) ~= "number" or timeout ~= timeout or timeout < 0 then
		FormatMessage.Warn(
			`Startup.{functionName} needs a timeout of 0 seconds or more, got {tostring(timeout)}. It waits without one.`
		)

		return nil
	end

	return timeout
end

--[[
	@yields

	Waits until isDone() is true or the signal fires, for at most timeout seconds (forever when nil). Returns whether
	it finished in time.
]]
local function waitFor(isDone: () -> boolean, signal: typeof(SchemaStore.Initialized), timeout: number?): boolean
	if isDone() then
		return true
	end

	local thread = coroutine.running()
	local finished = false

	local function finish(success: boolean)
		if finished then
			return
		end
		finished = true

		--the waiting thread may have been cancelled or closed with its script by now; resuming it then would error
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, success)
		end
	end

	local disconnect = signal:Once(function()
		finish(true)
	end)
	local timer = if timeout then task.delay(timeout, finish, false) else nil

	local success = coroutine.yield()

	disconnect()
	if timer and coroutine.status(timer) == "suspended" then
		task.cancel(timer)
	end

	return success
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
		FormatMessage.Warn("Startup.InitServer only works on the server. Nothing was started.")

		return
	end
	if failed then
		FormatMessage.Warn(
			"Startup.InitServer already failed earlier in this session, so sounds stay off for this server. See the warning above. This call was ignored."
		)

		return
	end
	if starting or SchemaStore.IsInitialized() then
		FormatMessage.Warn("Startup.InitServer was already called. The second call was ignored.")

		return
	end
	if typeof(soundFolder) ~= "Instance" then
		FormatMessage.Warn(
			`Startup.InitServer needs the SOUNDS Configuration, got {typeof(soundFolder)}. Sounds are off for this server.`
		)

		return
	end
	starting = true

	--anything that goes wrong while starting turns sounds off instead of breaking the script that called this
	local success, reason = pcall(startServer :: any, soundFolder)
	if not success then
		failed = true
		FormatMessage.Warn(`The library could not start, so sounds are off for this server: {reason}`)
	end
end

startServer = function(soundFolder: Configuration)
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

	--published first: if publishing fails, no SoundGroups or holders are left half-made for clients to wait on
	clock = os.clock()
	Transport.Publish(schemaBuffer)
	SchemaStore.LoadServer(schemaBuffer)
	timings.Publish = os.clock() - clock

	SchemaStore.SetInitialized()

	--the server has nothing to preload, so anything waiting on preloads there resumes right away
	SchemaStore.SetPreloaded()
end

--[=[
	@within Startup

	@client

	@yields

	Receives the schema from the server, then builds and preloads every sound tagged for preloading. It can be
	called from `ReplicatedFirst`, for example to play sounds on a loading screen; it waits for the schema to arrive.
	If the schema has not arrived after 30 seconds, because the server could not start, it warns and returns with
	sounds off for this player.

	The library is ready as soon as the schema is received, so `WaitUntilReady` and `OnReady` in other scripts resume
	then. This call itself yields until the preloads finish or `timeout` seconds pass, whichever comes first, and
	warns if it timed out. Pass `0` to not wait at all: the preloads still run in the background, no warning is
	printed, and you can check on them with `IsPreloaded` or `WaitUntilPreloaded`.

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
		FormatMessage.Warn("Startup.InitClient only works on the client. Nothing was started.")

		return
	end
	if failed then
		FormatMessage.Warn(
			"Startup.InitClient already failed earlier in this session, so sounds stay off for this player. See the warning above. This call was ignored."
		)

		return
	end
	if starting or SchemaStore.IsInitialized() then
		FormatMessage.Warn("Startup.InitClient was already called. The second call was ignored.")

		return
	end

	local realTimeout = timeout or DEFAULT_PRELOAD_TIMEOUT
	if type(realTimeout) ~= "number" or realTimeout ~= realTimeout or realTimeout < 0 then
		FormatMessage.Warn(
			`Startup.InitClient timeout must be a number of 0 or more, got {tostring(timeout)}. Using {DEFAULT_PRELOAD_TIMEOUT}.`
		)
		realTimeout = DEFAULT_PRELOAD_TIMEOUT
	end
	starting = true

	local success, reason = pcall(startClient :: any)
	if not success then
		failed = true
		FormatMessage.Warn(`The library could not start, so sounds are off for this player: {reason}`)

		return
	end

	if realTimeout > 0 and not waitFor(SchemaStore.IsPreloaded, SchemaStore.Preloaded, realTimeout) then
		FormatMessage.Warn(`Preloading did not finish within {realTimeout} seconds. Continuing without waiting.`)
	end
end

startClient = function()
	local timings = SchemaStore.Timings
	local clock = os.clock()

	--one deadline for the schema and the instances it needs; raised errors land in InitClient's pcall and its warning
	local deadline = clock + SCHEMA_TIMEOUT

	local schemaBuffer, reason = Transport.Receive(deadline)
	if not schemaBuffer then
		error(`after {SCHEMA_TIMEOUT} seconds, {reason}`, 0)
	end
	timings.Receive = os.clock() - clock

	clock = os.clock()
	SchemaStore.LoadClient(schemaBuffer, deadline)

	--the templates keep the assets referenced so they stay loaded for the session
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
end

------------------------------------------------------------------------------------------------------------------------

--[=[
	@within Startup

	```lua
	print(VluxySF.Startup.IsReady())
	```

	@return boolean -- Whether the library has started on this side.
]=]
function Startup.IsReady(): boolean
	return SchemaStore.IsInitialized()
end

--[=[
	@within Startup

	@yields

	Yields until the library has started on this side, or until `timeout` seconds pass. Returns right away if it
	already has.

	```lua
	VluxySF.Startup.WaitUntilReady()

	VluxySF.OneShot("MySound")
	```

	```lua
	if not VluxySF.Startup.WaitUntilReady(10) then
		warn("Sounds did not start within 10 seconds")
	end
	```

	@param timeout number? -- The longest to wait, in seconds. Waits forever when not given.

	@return boolean -- `true` once ready, `false` if the timeout passed first.
]=]
function Startup.WaitUntilReady(timeout: number?): boolean
	return waitFor(SchemaStore.IsInitialized, SchemaStore.Initialized, checkTimeout(timeout, "WaitUntilReady"))
end

--[=[
	@within Startup

	Runs the callback once the library has started, without yielding. If it already has, the callback runs in a new
	thread right away. An error in the callback does not stop startup or other callbacks.

	```lua
	VluxySF.Startup.OnReady(function()
		VluxySF.OneShot("MySound")
	end)

	-- This line does not wait.
	```

	@param callback () -> () -- Runs once the library is ready.

	@return () -> () -- Cancels the callback if it has not run yet.
]=]
function Startup.OnReady(callback: () -> ()): () -> ()
	if SchemaStore.IsInitialized() then
		local thread = task.spawn(callback)

		return function()
			if coroutine.status(thread) == "suspended" then
				task.cancel(thread)
			end
		end
	end

	return SchemaStore.Initialized:Once(callback)
end

--[=[
	@within Startup

	```lua
	print(VluxySF.Startup.IsPreloaded())
	```

	@return boolean -- Whether the sounds tagged for preloading have finished loading. Always `true` on the server
	once it has started, since the server preloads nothing.
]=]
function Startup.IsPreloaded(): boolean
	return SchemaStore.IsPreloaded()
end

--[=[
	@within Startup

	@yields

	Yields until the sounds tagged for preloading have finished loading, or until `timeout` seconds pass. Returns right
	away if they have. Useful after `InitClient(0)`.

	```lua
	VluxySF.Startup.InitClient(0)

	-- Do other startup work here.

	VluxySF.Startup.WaitUntilPreloaded()
	```

	@param timeout number? -- The longest to wait, in seconds. Waits forever when not given.

	@return boolean -- `true` once preloaded, `false` if the timeout passed first.
]=]
function Startup.WaitUntilPreloaded(timeout: number?): boolean
	return waitFor(SchemaStore.IsPreloaded, SchemaStore.Preloaded, checkTimeout(timeout, "WaitUntilPreloaded"))
end

return Startup
