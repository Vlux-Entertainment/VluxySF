---
sidebar_position: 3
---


# Initialization

To start using VluxySF, you must initialize the package on both the server and the client. This ensures all sound data is available and ready for use.

---

## 1. Setting Up the Sound Folder

First, create a `Configuration` named `SOUNDS` and put it in `ServerStorage`. This should containing all your sound instances that you want to use for this library. For details on organizing this folder, see [Folder Setup](/docs/FolderSetup).



*It is required that you do this or unexpected behavior may occur!*

---

## 2. Server Initialization

On the server, inject the `Configuration` containing your instanced sounds:

```lua
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

-- Reference to the folder/config of the actual sounds you want to use
local soundFolder = ServerStorage:FindFirstChild("SOUNDS")

-- Initialize the server
VluxySF.Startup.InitServer(soundFolder)

-- <--schema can be used here
```

---

## 3. Client Initialization

On the client its a very similar setup:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

-- Initialize the client
VluxySF.Startup.InitClient()

-- <--schema can be used here
```
*For initializing the client you can also provide a timeout for any sounds you tagged for preloading*

## 4. Basic Use

In order to fully use this library in other modules you need to wait for the schema:

```lua
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

    -- wait for schema to be ready
    VluxySF.Startup.WaitForSchema()

    -- <--schema can be used here
```
*If you know with 100% certaintly that the schema is loaded you do not need to use the wait function.*

## 4. Advanced Use

You can also use this library in a more [Unity](https://unity.com/) styled way.

This method doesnt need `WaitForSchema()` to function.

*You will have to make your own system to achieve this, this is commonly done through a module loader!*

*server init module*
```lua
    local ServerStorage = game:GetService("ServerStorage")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

    -- Reference to the folder/config of the actual sounds you want to use
    local soundFolder = ServerStorage:FindFirstChild("SOUNDS")

    local Orchestrator = {}

    Orchestrator.Init = function()
        VluxySF.Startup.InitServer(SOUNDS)
    end

    Orchestrator.Start = function()
        -- <--schema can be used here
    end

    return Orchestrator
```

*client init module*
```lua
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

    local Orchestrator = {}

    Orchestrator.Init = function()
        VluxySF.Startup.InitClient() <--yeilds until ready
    end

    Orchestrator.Start = function()
        -- <--schema can be used here
    end

    return Orchestrator
```

*new client module*
```lua
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

    local Orchestrator = {}

    Orchestrator.Start = function()
        -- <--schema can be used here
    end

    return Orchestrator
```

*You can also use the Schema in sub modules instead of directly calling them from an `Orchestrator` if they run on `Start` or after.*

---
