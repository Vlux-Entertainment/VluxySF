---
sidebar_position: 8
---

# Preloading

A sound's audio has to download before it can be heard. The first time a sound plays, that can mean a short silence. Preloading downloads the audio ahead of time and keeps it loaded for the whole session, so the sound plays the moment you need it.

Preloading only happens on the client, where sounds are heard.

:::tip
Preloading is about the **audio**. To keep a built `Sound` ready for fast fetching instead, see [Warming and Chilling](./Warming.md).
:::

---

## Preloading from Studio

The easiest way is to tag sounds in Studio with `VluxySF_Preload`:

- Tag a **Sound** to preload that one sound.
- Tag a **Folder** or any other container to preload every sound inside it.
- Tag a **group Configuration** to preload the whole group.

```
SOUNDS⚙️
  └─ SFX⚙️
       ├─ UI📁                 ← Tagged: every sound inside preloads
       │    ├─ Click🔊
       │    └─ Hover🔊
       └─ Explosion🔊          ← Tagged: only this sound preloads
```

You can add a tag from the **Tags** section at the bottom of the Properties window.

Tagged sounds are preloaded by `Startup.InitClient`.

---

## Waiting for preloads

`InitClient` waits for the tagged sounds to load, for at most its timeout in seconds. The default is 5:

```lua
VluxySF.Startup.InitClient(10) -- Waits up to 10 seconds for the tagged sounds.
```

If the time runs out, a warning is printed and the sounds keep loading in the background.

For the fastest possible start, pass `0`. `InitClient` returns right away, the sounds load in the background, and you can wait for them later where it matters:

```lua
VluxySF.Startup.InitClient(0)

-- Other startup work runs while the audio downloads.

VluxySF.Startup.WaitUntilPreloaded() -- Yields until the tagged sounds are loaded.
```

`WaitUntilPreloaded` also takes a timeout and returns `false` if it ran out first. `Startup.IsPreloaded()` checks without waiting.

---

## Preloading at runtime

Preload more sounds by name whenever you know they are coming up, like when a player enters a new area:

```lua
VluxySF.Preload.AddAsync("BossTheme", "BossRoar") -- Yields until their audio is loaded.

print(VluxySF.Preload.Has("BossRoar")) -- true
print(VluxySF.Preload.GetNames()) -- Every preloaded sound.
```

---

## What to preload

Preload the sounds that must play instantly the first time: UI clicks, the main music, common combat sounds.

:::warning
A preloaded sound stays loaded for the whole session, and there is no way to undo it. Do not preload everything. For sounds that only matter for a while, like one map's ambience, [warm](./Warming.md) them instead and chill them when you are done.
:::

See [Performance and Memory](./Performance.md) for how much preloading costs.
