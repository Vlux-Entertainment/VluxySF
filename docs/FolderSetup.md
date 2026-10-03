---
sidebar_position: 3
---

# Folder Setup

All of your sounds live in one place: a `Configuration` named `SOUNDS` inside `ServerStorage`.
VluxySF uses the layout of that Configuration to group your sounds and to know which ones to preload.

**You do not need to create or assign SoundGroups yourself!**

---

## The basics

**Legend:**
```
⚙️ = Configuration Instance
📁 = Folder Instance
🔊 = Sound Instance
```

**Example:**
```
SOUNDS⚙️               ← The base Configuration
  ├─ MUSIC⚙️           ← Becomes the MUSIC SoundGroup
  │    ├─ mainTheme🔊  ← Grouped to MUSIC
  │    └─ battle🔊     ← Grouped to MUSIC
  └─ SFX⚙️             ← Becomes the SFX SoundGroup
        ├─ click🔊     ← Grouped to SFX
        └─ explosion🔊 ← Grouped to SFX
```

There are only three rules:

1. **Every direct child of `SOUNDS` is a `Configuration`.** Each one becomes a `SoundGroup` with the same name. A `Folder` or `Sound` placed directly under `SOUNDS` throws an error on startup.
2. **Every `Sound` goes inside one of those group Configurations.** It is assigned to that `SoundGroup` automatically.
3. **Every `Sound` has a unique name.** The name is the key you fetch it with, like `VluxySF.Fetch("explosion")`. If two sounds share a name, a warning appears at runtime and only one of them is kept.

### Naming conventions

| Instance | Recommended | Required? |
|---|---|---|
| SoundGroup Configurations | `UPPER_CASE` | No, any name works |
| Folders | `PascalCase` | No, any name works |
| Sounds | `PascalCase` or `camelCase` | No, but the name must be unique |

---

## Organizing with folders

Inside a group you can use Folders (📁) however you like.

```
SOUNDS⚙️
  └─ SFX⚙️
      ├─ UI📁
      │    └─ click🔊
      └─ Game📁
          └─ explosion🔊
```

:::tip
The hierarchy inside a group does not affect the library. Sounds are always fetched by name, so you can reorganize your folders at any time without touching your code.
:::

---

## Preloading sounds

Want certain sounds to be ready instantly? Give a `Sound` or a `Folder` the tag `VluxySF_Preload`, and it is preloaded as soon as the client starts.

- Tag a **Sound** to preload that one sound.
- Tag a **Folder** to preload every sound inside it.

```
SOUNDS⚙️
  ├─ MUSIC⚙️
  │    ├─ mainTheme🔊
  │    └─ battles📁                      ← Tagged "VluxySF_Preload": both sounds inside preload
  │         ├─ importantSound1🔊
  │         └─ importantSound2🔊
  └─ SFX⚙️
        ├─ click🔊
        └─ explosions📁
             ├─ commonExplosion🔊         ← Tagged "VluxySF_Preload": only this sound preloads
             └─ uncommonLongExplosion🔊
```

You can add a tag in Studio from the **Tags** section at the bottom of the Properties window.

:::warning
Only preload the sounds that need it. A preloaded sound stays in memory for the whole session, and there is no way to undo it. See [Advice](./Advice.md#memory-optimizations) for more.
:::

### Preload timeout

The client waits for the tagged sounds to preload before it continues. You can pass a timeout (in seconds) to `InitClient`. If preloading takes longer than that, the client continues and the sounds keep loading in the background. The default is 5 seconds.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

local preloadTimeout = 10
VluxySF.Startup.InitClient(preloadTimeout)

-- Reaches this line once the sounds are preloaded or the timeout is reached.
```

---

## Configuring sounds

Set up each `Sound` in Studio exactly how you want it to play.

- **Properties:** Set `SoundId`, `Volume`, `PlaybackSpeed`, and so on directly on the `Sound`. Every property is kept except for the `Parent`.
- **Effects:** Add effects such as `EqualizerSoundEffect` or `ReverbSoundEffect` as children of the `Sound`.

:::note
- Only `SoundEffects` are kept. Any other instance parented to a `Sound` is skipped with a warning.
- Only one effect of each class is kept per `Sound`.
- A fetched effect is named after its class, so you can always reach it with `sound.EchoSoundEffect`, whatever it was called in Studio.
:::

---

## End result

When you are done, your `SOUNDS` Configuration should look something like this in Studio:

![Folder Structure Example](/SoundsConfigExample1.png)

:::note
The `SOUNDS` Configuration belongs in `ServerStorage`. Making it a direct child of that service is recommended.
:::

## Next step

Your sounds are ready. Continue to [Initialization](./Setup.md) to start the library.
