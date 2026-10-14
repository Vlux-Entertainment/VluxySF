---
sidebar_position: 5
---

# Starting the Library

VluxySF has to be started once on the server and once on each client. After that, every script can fetch sounds.

Before you start, make sure you have a `SOUNDS` Configuration in `ServerStorage`. See [Folder Setup](./FolderSetup.md) if you have not made one yet.

---

## 1. Start the server

In a server script, give the library your `SOUNDS` Configuration:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitServer(ServerStorage.SOUNDS)

-- The schema can be used from here on.
```

`InitServer` compiles every sound into the schema and publishes it. Clients receive the schema when they join; a client that cannot read it asks the server for it once. Nothing else is requested from the server at runtime.

:::info
`InitServer` detaches the `SOUNDS` Configuration right away and destroys it shortly after, once the calling thread yields or finishes. Your Configuration in Studio is not changed.

The schema is locked once it is created, so sounds and SoundGroups cannot be added while the game is running.
:::

---

## 2. Start the client

In a client script, the setup is very similar:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitClient() -- Yields until the tagged sounds are preloaded, or 5 seconds pass.

-- The schema can be used from here on.
```

`InitClient` receives the schema, then preloads the sounds you tagged for [preloading](./Preloading.md).

### The preload timeout

`InitClient` takes one optional argument: how many seconds to wait for the preloads. The default is `5`.

- `InitClient()` or `InitClient(seconds)` yields until the preloads finish or the timeout passes, whichever comes first. If it timed out, a warning is printed and the preloads keep going in the background.
- `InitClient(0)` does not wait for the preloads at all. No warning is printed. The preloads still run in the background.
- A negative or invalid timeout prints a warning and the default is used.

Either way, the library is ready as soon as the schema is received, before the preload wait. Other scripts waiting with `WaitUntilReady` resume at that point, even while `InitClient` is still waiting for the preloads. Fetching a sound that is still preloading works; Roblox plays it as soon as its audio arrives.

When you do not wait, `Startup.IsPreloaded()` tells you whether the tagged sounds have finished loading, and `Startup.WaitUntilPreloaded()` yields until they have:

```lua
VluxySF.Startup.InitClient(0) -- Does not wait for the preloads.

-- Do other startup work here.

print(VluxySF.Startup.IsPreloaded()) -- true or false

VluxySF.Startup.WaitUntilPreloaded() -- Yields until the tagged sounds are loaded.
```

`WaitUntilPreloaded` returns right away if the preloads are already done. It also takes an optional timeout and returns `false` if the timeout passed first. On the server, which preloads nothing, both report the preloads as done once `InitServer` has run.

:::danger
Call `InitServer` once on the server and `InitClient` once on each client. A second call prints a warning and is ignored.
:::

:::info
Starting never breaks the script that calls it. If something goes wrong, for example `InitServer` is given something that is not your `SOUNDS` Configuration, a warning explains it and sounds stay off: fetches return blank sounds or `nil`, and nothing else in the library errors. A `SOUNDS` child that is not a Configuration, or a second group with a name already used, is skipped with a warning and the rest still works.

A client waits at most 30 seconds for the schema. If the server could not start, `InitClient` warns and returns with sounds off for that player instead of holding its script forever.
:::

---

## 3. Use it from other scripts

Functions used before the library is ready do not error, but they do nothing useful: each one warns once and returns a blank sound, `nil` or an empty result. Any script that is not the one that started the library should wait for it first:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.WaitUntilReady() -- Yields until the library is ready.

-- The schema can be used from here on.
```

`WaitUntilReady` takes an optional timeout in seconds and returns `false` if it passed first, so a script never hangs forever if the server failed to start:

```lua
if not VluxySF.Startup.WaitUntilReady(15) then
	warn("Sounds are not available")
end
```

If you do not want your script to yield, use `OnReady`. It runs the callback once the library is ready, or right away in a new thread if it already is. It returns a function that cancels the callback if it has not run yet:

```lua
local cancel = VluxySF.Startup.OnReady(function()
	VluxySF.OneShot("LoFiBeat1")
end)

-- This line runs right away.
```

:::tip
If you are certain your code runs after the schema is loaded, you do not need to wait at all. `VluxySF.Startup.IsReady()` tells you whether it is ready.
:::

See [Startup](/api/Startup) for every function on this page.

---

## Advanced: start it from a module loader

If your game loads its modules in phases, like `Init` and then `Start`, you can start VluxySF during `Init`. Everything that runs on `Start` or later can then use the schema without waiting.

*You have to bring your own module loader for this. This is commonly called a single script architecture.*

**Server module that starts the library:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local Orchestrator = {}

function Orchestrator.Init()
	VluxySF.Startup.InitServer(ServerStorage.SOUNDS)
end

function Orchestrator.Start()
	-- The schema can be used here.
end

return Orchestrator
```

**Client module that starts the library:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local Orchestrator = {}

function Orchestrator.Init()
	VluxySF.Startup.InitClient() -- Yields until the tagged sounds are preloaded, or 5 seconds pass.
end

function Orchestrator.Start()
	-- The schema can be used here.
end

return Orchestrator
```

**Any other module:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local MyModule = {}

function MyModule.Start()
	-- The schema can be used here, without WaitUntilReady.
end

return MyModule
```

:::note
This only works if your loader finishes every `Init` before it runs any `Start`. Sub modules can use the schema too, as long as they run on `Start` or after.

If your loader does not want `Init` to yield, call `InitClient(0)` there instead and use `WaitUntilPreloaded` later where the preloaded sounds matter.
:::

## Next step

The library is running. Continue to [Fetching Sounds](./Fetching.md) to play your first sound.
