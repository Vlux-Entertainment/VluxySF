---
sidebar_position: 4
---

# Folder Setup

All of your sounds live in one place: a `Configuration` named `SOUNDS` inside `ServerStorage`.
VluxySF reads the layout of that Configuration once on the server to group your sounds and to know which ones to preload.

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

1. **Every direct child of `SOUNDS` is a `Configuration` with a unique name.** Each one becomes a `SoundGroup` with the same name. A `Folder` or `Sound` placed directly under `SOUNDS`, or a second group with a name already used, is skipped by `InitServer` with a warning, along with everything inside it.
2. **Every `Sound` goes inside one of those group Configurations.** It is assigned to that `SoundGroup` automatically.
3. **Every `Sound` has a unique name.** The name is the key you fetch it with, like `VluxySF.Fetch("explosion")`. If two sounds share a name, a warning is printed on the server and only the first one is kept.

### Naming conventions

| Instance | Recommended | Required? |
|---|---|---|
| SoundGroup Configurations | `UPPER_CASE` | No, any name works |
| Folders | `PascalCase` | No, any name works |
| Sounds | `PascalCase` or `camelCase` | No, but the name must be unique |

---

## Organizing with folders

Inside a group you can use Folders (📁) however you like. Any other instance that is not a `Sound`, such as a nested `Configuration` or a `Model`, is treated the same way as a `Folder`.

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

Tag a `Sound`, a Folder or a whole group Configuration with `VluxySF_Preload` to have its sounds downloaded when a client starts, so they play instantly the first time. [Preloading](./Preloading.md) explains how it works and what to tag.

---

## Configuring sounds

Set up each `Sound` in Studio exactly how you want it to play.

- **Properties:** Set `SoundId`, `Volume`, `PlaybackSpeed`, and so on directly on the `Sound`. A fetched sound comes out the way you authored it. `Parent`, `Archivable`, attributes, tags, read-only state such as `IsPlaying` and `TimeLength`, playback state (`Playing` and `TimePosition`: a sound in `SOUNDS` is never playing, and a fetched sound is always stopped at the start), and deprecated properties such as `Pitch`, `MinDistance`, `MaxDistance` and `EmitterSize` are not kept.
- **Effects:** Add effects such as `EqualizerSoundEffect` or `ReverbSoundEffect` as children of the `Sound`.

:::note
- Only `SoundEffects` are kept. Any other instance parented to a `Sound` is skipped with a warning.
- Only one effect of each class is kept per `Sound`. Extra ones are skipped with a warning.
- A fetched effect is named after its class, so you can always reach it with `sound.EchoSoundEffect`, whatever it was called in Studio.
- A `SoundEffect` cannot have children. Children are not kept, and a warning is printed.
:::

---

## End result

When you are done, your `SOUNDS` Configuration should look something like this in Studio:

![Folder Structure Example](/SoundsConfigExample1.png)

:::note
Keep the `SOUNDS` Configuration in `ServerStorage` so it never replicates to clients. `InitServer` takes the Configuration as an argument, so where exactly it sits is up to you.
:::

Once `InitServer` has compiled it, the Configuration is detached right away and destroyed shortly after, once the calling thread yields or finishes. Nothing else should read from it after that.

## Next step

Your sounds are ready. Continue to [Starting the Library](./Setup.md).
