---
sidebar_position: 4
---

# Initialization

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

`InitServer` compiles every sound into the schema and publishes it. Clients receive the schema when they join, so nothing is requested from the server at runtime.

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

`InitClient` receives the schema, then builds and preloads the sounds you tagged for [preloading](./FolderSetup.md#preloading-sounds).

### The preload timeout

`InitClient` takes one optional argument: how many seconds to wait for the preloads. The default is `5`.

- `InitClient()` or `InitClient(seconds)` yields until the preloads finish or the timeout passes, whichever comes first. If it timed out, a warning is printed and the preloads keep going in the background.
- `InitClient(0)` does not wait for the preloads at all. No warning is printed. The preloads still run in the background.
- A negative timeout throws an error.

Either way, the schema is ready as soon as it is received, before the preload wait. Other scripts waiting with `WaitForSchema` resume at that point, even while `InitClient` is still waiting for the preloads. Fetching a sound that is still preloading works; the engine finishes loading it when it plays.

When you do not wait, `Startup.IsPreloaded()` tells you whether the tagged sounds have finished loading, and `Startup.WaitForPreload()` yields until they have:

```lua
VluxySF.Startup.InitClient(0) -- Does not wait for the preloads.

-- Do other startup work here.

print(VluxySF.Startup.IsPreloaded()) -- true or false

VluxySF.Startup.WaitForPreload() -- Yields until the tagged sounds are loaded.
```

Both functions are client only. `WaitForPreload` returns right away if the preloads are already done.

:::danger
Call `InitServer` once on the server and `InitClient` once on each client. Calling either one twice throws an error.
:::

---

## 3. Use it from other scripts

Most functions in the library throw an error when they are used before the schema is ready. Any script that is not the one that started the library should wait for the schema first:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.WaitForSchema() -- Yields until the schema is ready.

-- The schema can be used from here on.
```

If you do not want your script to yield, use `ConnectForSchema`. It runs the callback once the schema is ready, or right away in a new thread if it already is. It returns a function that cancels the callback if it has not run yet:

```lua
local cancel = VluxySF.Startup.ConnectForSchema(function()
	VluxySF.FetchPlayOnce("LoFiBeat1")
end)

-- This line runs right away.
```

:::tip
If you are certain your code runs after the schema is loaded, you do not need to wait at all. `VluxySF.Startup.IsInitialized()` tells you whether it is ready.
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
	-- The schema can be used here, without WaitForSchema.
end

return MyModule
```

:::note
This only works if your loader finishes every `Init` before it runs any `Start`. Sub modules can use the schema too, as long as they run on `Start` or after.

If your loader does not want `Init` to yield, call `InitClient(0)` there instead and use `WaitForPreload` later where the preloaded sounds matter.
:::

## Next step

The library is running. Continue to [Examples](./Examples.md) to start playing sounds.
