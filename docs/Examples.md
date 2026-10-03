---
sidebar_position: 5
---

# Examples

Practical ways to use VluxySF, from playing one sound to managing volume settings and memory.

Every example assumes the library is [initialized](./Setup.md) and starts like this:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.WaitForSchema() -- Wait until the schema is loaded.
```

:::note
Names like `"LoFiBeat1"` are example `Sound` names. Replace them with the names of sounds in your own `SOUNDS` Configuration.
:::

---

## Fetching sounds

### Fetch

This is the main function of the library! It rebuilds your sound on request and always gives you a `Sound`.

```lua
local sound = VluxySF.Fetch("LoFiBeat1") -- Always returns a Sound.

-- Do stuff here / adjust properties.

sound:Play()
```

If the sound cannot be found, a warning appears and a blank `Sound` is returned instead, so your code keeps running.

### FetchStrict

Use `FetchStrict` if you would rather get `nil` than a blank `Sound` when something goes wrong.

```lua
local sound = VluxySF.FetchStrict("LoFiBeat1") -- Can return nil.

if sound then
	-- Do stuff here / adjust properties.

	sound:Play()
end
```

### FetchPlayOnce

If you just need a one shot, `FetchPlayOnce` fetches the sound, plays it once, and destroys it when it ends.

```lua
VluxySF.FetchPlayOnce("LoFiBeat1")
```

It returns a cleanup function that you can call to stop and destroy the sound early:

```lua
local stopSound = VluxySF.FetchPlayOnce("LongExplosion1")

task.wait(1)

stopSound()
```

### Choosing a parent

The second argument of every fetch function is the parent. Give it a `BasePart` or an `Attachment` to play the sound in 3D space.

```lua
local door = workspace.Door

VluxySF.FetchPlayOnce("DoorCreak1", door) -- Plays from the door.
```

:::info
A sound that is fetched without a parent is placed in a Configuration named `UnattachedSounds` inside `SoundService`. It stays there until you destroy it, so call `sound:Destroy()` once you are done with a sound you fetched yourself.
:::

---

## Presets

A preset is a function that receives the `Sound` and changes it. Pass one as the third argument of a fetch function to set up the sound the same way every time.

```lua
local presets = VluxySF.Presets

-- Combine lets you merge multiple presets into one.
local myPreset = presets.Combine(
	presets.NaturalVolumeJitter(0.8, 0.12),
	presets.NaturalPlaybackJitter(0.7, 0.09),
	presets.Parent(workspace)
)

VluxySF.FetchPlayOnce("RandomSound1", nil, myPreset)
task.delay(0.1, function()
	VluxySF.FetchPlayOnce("RandomSound1", nil, myPreset)
end)

-- This sound should use the same preset, but with a different parent.
local sound = VluxySF.Fetch("RandomSound1", workspace.CurrentCamera, myPreset)

-- This sound is different, but it should play in a similar way.
local otherSound = VluxySF.Fetch("OtherRandomSound1", nil, myPreset)
```

### Making your own presets

A preset is any function that takes a `Sound`. Wrap it in another function when it needs settings:

```lua
local function randomName(name: string): (Sound) -> ()
	return function(sound: Sound)
		sound.Name = name .. math.random()
	end
end

local myPreset = VluxySF.Presets.Combine(
	randomName("Footstep"),
	VluxySF.Presets.Volume(0.6)
)

local sound = VluxySF.Fetch("Footstep1", nil, myPreset)
```

:::tip
You can keep your own presets in a module and use them just like the built in ones.
:::

:::note
- Combined presets are applied in order, from the first argument to the last.
- It is recommended that you only use presets to set properties and do similar one time work.
:::

### Jitter

The jitter presets above are built from `VluxySF.Jitter`, which you can also use on its own. A jitter is a function that gives you a slightly different number each time you call it.

```lua
local pitchJitter = VluxySF.Jitter.UnitLog(1, 0.15) -- Stays close to 1.

local function playFootstep()
	local sound = VluxySF.Fetch("Footstep1")
	sound.PlaybackSpeed = pitchJitter()
	sound:Play()
end
```

`Jitter.UnitLog` favors values near the center, which makes repeated sounds like footsteps feel more natural. See the [Jitter API](/api/Jitter) for the other kinds.

---

## SoundGroups

Every group Configuration in your `SOUNDS` Configuration becomes a `SoundGroup`, and all of them sit under one main `SoundGroup`. That gives you a main volume and a volume for each group.

Volumes can be set on the server or the client. The client is recommended for player settings.

```lua
local mainVolume = 0.8
local groupVolumes = {
	GAME = 0.7,
	MUSIC = 0.55,
	SFX = 0.64,
}

local function onSettingsChanged()
	-- Do stuff here if you want, like clamping your values. A SoundGroup volume can go from 0 to 10.

	VluxySF.Groups.SetVolumes(mainVolume, groupVolumes)
end

onSettingsChanged()
```

:::tip
Call this whenever a slider or setting changes to update the volumes live.
:::

:::note
- The main volume is optional. Pass `nil` to leave it as it is.
- You only need to list the groups you want to change.
- There are more functions for working with your SoundGroups. See the [SoundGroups API](/api/SoundGroups).
:::

---

## Keeping sounds ready

A sound that is fetched for the first time has to be created and loaded, which can take a moment. On the client, there are two ways to have a sound ready before you need it.

### Preload

A preloaded sound stays loaded for the whole session. The easiest way is to [tag it in Studio](./FolderSetup.md#preloading-sounds), but you can also preload by name at runtime:

```lua
VluxySF.Preload.Selected("BossTheme1", "BossRoar1") -- Yields until they are loaded.
```

### Warm and chill

Warming keeps a sound loaded only for as long as you need it. Warm it before the moment it matters, and chill it afterwards to let it go.

```lua
VluxySF.Cache.Warm("BossTheme1", "BossRoar1") -- Ready to play without a delay.

-- Later, during the boss fight.
VluxySF.FetchPlayOnce("BossRoar1")

-- The fight is over, so these sounds are not needed anymore.
VluxySF.Cache.Chill("BossTheme1", "BossRoar1")
```

:::note
- `Preload` and `Cache` only work on the client.
- Chilling a sound does not unload it while other sounds with the same `SoundId` still exist.
:::

See [Advice](./Advice.md#memory-optimizations) for when to use each one.

---

## Reading the schema

You can read what the library knows about your sounds at any time.

```lua
print(VluxySF.Schema.GetNames()) -- Every sound name.
print(VluxySF.Schema.GetDefinition("LoFiBeat1")) -- The stored properties and effects of one sound.
print(VluxySF.Groups.GetNames()) -- Every SoundGroup name.
```
