---
sidebar_position: 5
---

# Examples

Practical ways to use VluxySF, from playing one sound to managing volume settings and memory.

Every example assumes the library is [initialized](./Setup.md) and starts like this:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.WaitUntilReady() -- Wait until the schema is ready.
```

:::note
Names like `"LoFiBeat1"` are example `Sound` names. Replace them with the names of sounds in your own `SOUNDS` Configuration.
:::

---

## Fetching sounds

### Fetch

This is the main function of the library! It builds your sound on request and always gives you a `Sound`.

```lua
local sound = VluxySF.Fetch("LoFiBeat1") -- Always returns a Sound.

-- Do stuff here / adjust properties.

sound:Play()
```

If the name is not in the schema, a warning appears and a blank `Sound` named `VluxySF_Blank_Sound` is returned instead, so your code keeps running.

### TryFetch

Use `TryFetch` if you would rather get `nil` than a blank `Sound` when the name is not in the schema, for example when the name is built at runtime. It still prints a warning. To check a name without a warning, use `VluxySF.Schema.Has(name)`.

```lua
local sound = VluxySF.TryFetch("LoFiBeat1") -- Can return nil.

if sound then
	-- Do stuff here / adjust properties.

	sound:Play()
end
```

### OneShot

If you just need a one-shot, `OneShot` fetches the sound, plays it once, and destroys it when it ends. Looping is turned off. If the name is not in the schema, it warns and plays nothing.

```lua
VluxySF.OneShot("LoFiBeat1")
```

It returns a cleanup function that you can call to stop and destroy the sound early:

```lua
local stopSound = VluxySF.OneShot("LongExplosion1")

task.wait(1)

stopSound()
```

You never have to wait for a one-shot's audio to load: Roblox holds the sound until its audio arrives, then plays it from the beginning. A sound whose audio never loads (deleted, moderated or private) is destroyed after 10 seconds with a warning, so nothing is left behind.

### Choosing a parent

The second argument of every fetch function is the parent. Give it a `BasePart` or an `Attachment` to play the sound in 3D space.

```lua
local door = workspace.Door

VluxySF.OneShot("DoorCreak1", door) -- Plays from the door.
```

:::info
A sound that is fetched without a parent is placed in a Configuration named `UnattachedSounds` inside `SoundService`. It stays there until you destroy it, so call `sound:Destroy()` once you are done with a sound you fetched yourself.
:::

---

## Presets

A preset is a function that receives the `Sound` and changes it. Pass one as the third argument of a fetch function to set up the sound the same way every time. The preset runs before the sound is parented.

```lua
local presets = VluxySF.Presets

-- Combine lets you merge multiple presets into one.
local myPreset = presets.Combine(
	presets.NaturalVolumeJitter(0.8, 0.12),
	presets.NaturalPlaybackJitter(0.7, 0.09),
	presets.Parent(workspace)
)

VluxySF.OneShot("RandomSound1", nil, myPreset)
task.delay(0.1, function()
	VluxySF.OneShot("RandomSound1", nil, myPreset)
end)

-- This sound should use the same preset, but with a different parent. The parent argument wins over the preset.
local sound = VluxySF.Fetch("RandomSound1", workspace.CurrentCamera, myPreset)

-- This sound is different, but it should play in a similar way.
local otherSound = VluxySF.Fetch("OtherRandomSound1", nil, myPreset)
```

The built in presets are `Combine`, `Parent`, `Volume`, `PlaybackSpeed`, `NaturalVolumeJitter`, `NaturalPlaybackJitter`, `RandomVolumeJitter` and `RandomPlaybackJitter`. See the [Presets API](/api/Presets) for each one.

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

The jitter presets above are built from `VluxySF.Jitter`, which you can also use on its own. A jitter is a function that gives you a slightly different number each time you call it. Values never go below 0.

```lua
local pitchJitter = VluxySF.Jitter.Natural(1, 0.15) -- Stays close to 1.

local function playFootstep()
	local sound = VluxySF.Fetch("Footstep1")
	sound.PlaybackSpeed = pitchJitter()
	sound:Play()
end
```

`Jitter.Natural` favors values near the center, which makes repeated sounds like footsteps feel more natural. `Jitter.Uniform` spreads evenly around a center, and `Jitter.Range` picks a number between a minimum and a maximum. See the [Jitter API](/api/Jitter) for details.

---

## SoundGroups

Every group Configuration in your `SOUNDS` Configuration becomes a `SoundGroup`, and all of them sit under one main `SoundGroup` named `SOUNDS` in `SoundService`. That gives you a main volume and a volume for each group.

Set volumes on the client for player settings: a change there affects only that player. A change made on the server affects every player.

```lua
-- One slider for one group.
VluxySF.Groups.SetVolume("MUSIC", 0.55)

-- The main volume scales every group.
VluxySF.Groups.SetMainVolume(0.8)

-- Several groups at once, for example when loading saved settings.
VluxySF.Groups.SetVolumes({
	GAME = 0.7,
	MUSIC = 0.55,
	SFX = 0.64,
})
```

To save a player's settings, read them back with `GetVolumes` and `GetMainVolume`:

```lua
local saved = {
	Main = VluxySF.Groups.GetMainVolume(),
	Groups = VluxySF.Groups.GetVolumes(),
}

-- Later, after loading them:
VluxySF.Groups.SetMainVolume(saved.Main)
VluxySF.Groups.SetVolumes(saved.Groups)
```

:::note
- A volume has to be a number from 0 to 10. Anything else prints a warning and leaves the volume as it was.
- A group name that does not exist prints a warning and is skipped.
- `Groups.Get(name)`, `GetAll()`, `GetMain()` and `GetNames()` give you the `SoundGroup` instances themselves. See the [Groups API](/api/Groups).
:::

---

## Keeping sounds ready

On the client there are two separate tools for sounds that matter, and they solve different problems.

### Preload: have the audio downloaded

A sound's audio has to download before it can be heard. Preloading downloads it ahead of time and keeps it loaded for the whole session, so the sound plays without a delay the first time. The easiest way is to [tag it in Studio](./FolderSetup.md#preloading-sounds), but you can also preload by name at runtime:

```lua
VluxySF.Preload.AddAsync("BossTheme1", "BossRoar1") -- Yields until they are loaded.

print(VluxySF.Preload.Has("BossRoar1")) -- true
```

Sounds tagged in Studio are preloaded by `Startup.InitClient`. If you started the client with `InitClient(0)`, check on them with `Startup.IsPreloaded()` or wait with `Startup.WaitUntilPreloaded()`:

```lua
VluxySF.Startup.WaitUntilPreloaded() -- Yields until the tagged sounds are loaded.
```

### Warm and chill: keep a built sound ready

Warming builds a sound once, effects included, and keeps it so `Fetch` clones it instead of building it again. Warm it before the part of the game where it matters, and chill it afterwards to let it go.

```lua
VluxySF.Cache.Warm("BossTheme1", "BossRoar1")

-- Later, during the boss fight.
VluxySF.OneShot("BossRoar1")

-- The fight is over, so these sounds are not needed anymore.
VluxySF.Cache.Chill("BossTheme1", "BossRoar1")
```

:::note
- `Preload` and `Cache` only work on the client. On the server they warn once and do nothing.
- Keeping a warmed `Sound` also makes Roblox start downloading its audio, but warming does not wait for it. Use `Preload` when the audio has to be ready.
- Chilling destroys the kept copy. Sounds you already fetched are not affected.
:::

See [Advice](./Advice.md#memory-optimizations) for when to use each one.

---

## Reading the schema

You can read what the library knows about your sounds at any time.

```lua
print(VluxySF.Schema.GetNames()) -- Every sound name.
print(VluxySF.Schema.Has("LoFiBeat1")) -- Whether a sound exists, without a warning.
print(VluxySF.Schema.GetDefinition("LoFiBeat1")) -- The stored properties and effects of one sound.
print(VluxySF.Groups.GetNames()) -- Every SoundGroup name, in the order they appear under SOUNDS.
```

`GetDefinition` decodes one definition. `Schema.Get()` and `Schema.GetDefinitions()` decode every definition and freeze the table, so prefer `GetDefinition` or `Has` when you only need one.
