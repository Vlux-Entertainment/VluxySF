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

-- The Configuration that holds the sounds you want to use.
local soundFolder = ServerStorage:FindFirstChild("SOUNDS")

VluxySF.Startup.InitServer(soundFolder)

-- The schema can be used from here on.
```

:::info
`InitServer` reads every sound into the schema and then destroys the `SOUNDS` Configuration in the running game to save memory. Your Configuration in Studio is not changed.

The schema is locked once it is created, so sounds and SoundGroups cannot be added while the game is running.
:::

---

## 2. Start the client

In a client script, the setup is very similar:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitClient() -- Yields until the schema is ready.

-- The schema can be used from here on.
```

`InitClient` asks the server for the schema and then preloads the sounds you tagged for [preloading](./FolderSetup.md#preloading-sounds). You can pass a timeout for that preload as its first argument.

:::danger
Call `InitServer` once on the server and `InitClient` once on each client. Do not call them more than once.
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

If you do not want your script to yield, use `ConnectForSchema`:

```lua
VluxySF.Startup.ConnectForSchema(function()
	VluxySF.FetchPlayOnce("LoFiBeat1")
end)

-- This line runs right away.
```

:::tip
If you are certain your code runs after the schema is loaded, you do not need to wait at all. `VluxySF.Startup.IsInitialized()` tells you whether it is ready.
:::

---

## Advanced: start it from a module loader

If your game loads its modules in phases, like `Init` and then `Start`, you can start VluxySF during `Init`. Everything that runs on `Start` or later can then use the schema without waiting.

*You have to bring your own module loader for this. This is commonly called a single script architecture.*

**Server module that starts the library:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local soundFolder = ServerStorage:FindFirstChild("SOUNDS")

local Orchestrator = {}

function Orchestrator.Init()
	VluxySF.Startup.InitServer(soundFolder)
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
	VluxySF.Startup.InitClient() -- Yields until the schema is ready.
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
:::

## Next step

The library is running. Continue to [Examples](./Examples.md) to start playing sounds.
