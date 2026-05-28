---
sidebar_position: 5
---



# Examples

Explore practical usage patterns for VluxySF. These examples cover basic playback, group volume control, preloading, and advanced sound entity manipulation.

---
---

## Basic Fetch

This is the main function of this library! It reconstructs your sound on request.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.WaitForSchema() -- Wait until schema is loaded

local sound = VluxySF.Fetch("LoFiBeat1") -- <-- Always returns a Sound Instance.

--Do stuff here / adjust properties.

sound:Play()
```

> **Note:** `"LoFiBeat1"` is just an example `Sound` name in your `SOUNDS Configuration`.
>
> **Note:** If it fails to find your `Sound` a `Blank Sound Instance` is returned Instead.

## Basic OneShot

There is an alternative function for directly playing a sound if you just need to `OneShot`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.WaitForSchema() -- Wait until schema is loaded.

VluxySF.FetchPlayOnce("LoFiBeat1")
```

---

## Alternative Fetch

There is an alternative `Fetch Function` if you dont want a `Blank Sound Instance` on fail.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.WaitForSchema() -- Wait until schema is loaded.

local sound = VluxySF.FetchStrict("LoFiBeat1") -- <-- Can return nil.
if sound then
    --Do stuff here / adjust properties.

    sound:Play()
end

```

---

## Presets

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.WaitForSchema() --Wait until schema is loaded.

local presets = VluxySF.Presets --Quicker way to use presets.

--A combined preset as shown below lets you combine multiple presets together.
local myPrest = presets.Combine(
    function(name: string) -- <-- you can also make your own presets.
        return function(sound: Sound)
            sound.Name = name .. math.random()
        end
    end

    presets.NaturalVolumeJitter(0.8, 0.12),
    presets.NaturalPlaybackJitter(0.7, 0.09),
    presets.Parent(workspace),
)

VluxySF.FetchPlayOnce("RandomSound1", nil, nil, myPreset)
task.delay(0.1, function()
    VluxySF.FetchPlayOnce("RandomSound1", nil, nil, myPreset)
end)

--Want this sound to have a similar preset but the parent is diffrent.
local sound = VluxySF.Fetch("RandomSound1", nil, myPreset)
sound.parent = workspace.CurrentCamera

--This sound is diffrent but i want it to play similarly.
local sound = VluxySF.Fetch("OtherRandomSound1", nil, myPreset)
```
>**Tip:** You can make your own module of presets and use them just like shown here.
>
>**Note:** Combine presets get applied in order from first variable argument to last.
>
>**Note:** It is recommended that you only use presets to set properties and perform similar one time operations

---

## SoundGroups

Set the SoundGroup volumes at the start of a session. This can be done on server or client (client is recommended for user settings).


```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.WaitForSchema()

local mainVolume = 0.8
local subVolumes = {
    ["GAME"] = 0.7,
    ["MUSIC"] = 0.55,
    ["SFX"] = 0.64,
    ...
}

local function onUpdate()
    --Do stuff here if you want, maybe clamp your values if you dont want it to be from 0, 10

    VluxySF.Groups.SetVolumes(mainVolume, subVolumes)
end

--im too lazy to connect this to an event
task.spawn(function()
    while true do
        onUpdate()

        task.wait(0.5)
    end
end)
```

> **Tip:** You can call this function whenever a slider or setting changes to update volumes live.
>
> **Note:** inputing the `mainVolume` is optional. So are the elements in the `subVolumes` table.
>
> **Note:** There is other functions you can use for manipulating your `SoundGroups`.
