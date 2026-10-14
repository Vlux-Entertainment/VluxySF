---
sidebar_position: 13
---

# Performance and Memory

VluxySF is fast enough that you will rarely think about it. This page has the numbers, and the habits that keep sound memory low on phones and older devices.

---

## What it costs

Measured in Studio with 10,000 sounds that use real asset ids:

| | Cost |
|---|---|
| Starting the server | About 90 ms, once, before players join |
| Starting a client | About 10 ms, plus however long the [preloads](./Preloading.md) take to download |
| Size of all sound definitions | About 30 to 35 bytes per sound, compressed |
| Fetching a sound on the client | About 10 to 60 µs, mostly Roblox creating the `Sound` |
| Fetching a sound on the server | About 10 to 15 µs |

A frame at 60 FPS lasts about 16,700 µs, so even a busy moment with dozens of fetches is a small fraction of one.

---

## Keeping memory low

In short:

- Only preload the sounds that need to play instantly.
- Fetch a sound when you need it, not ahead of time.
- Destroy sounds when you are done with them. `OneShot` does it for you.
- Compress your audio files before uploading them.

### Preload only what needs it

Tagging a sound with `VluxySF_Preload` is easy, but a preloaded sound's audio stays in memory for the whole session, and there is no way to undo it. The more you preload, the more memory every player pays for.

If a sound only has to be ready for a while, like the sounds of one map, [warm it](./Warming.md) instead and chill it when you are done.

### Fetch late, destroy early

Call `Fetch` at the moment you need a sound, not when a script starts, and destroy it when you are done. A destroyed sound frees its memory, as long as no other sound with the same `SoundId` is still around and the audio was not preloaded.

### Avoid decoding everything

`Schema.Get()` and `Schema.GetDefinitions()` decode the definition of every sound and keep them all in memory, about 450 bytes each. That is fine for a debug tool, but not for gameplay code. Use `Schema.GetDefinition(name)` or `Schema.Has(name)` for one sound.

### Compress your audio

Shorter, smaller audio files are the biggest saving of all. Trim silence and lower the bitrate before uploading. It is the most work of these options, and Roblox limits how much audio you can upload each month, so save it for the sounds that matter.

---

## When to optimize

When you have a reason to: a memory warning on a device you target, or a polish pass before release. Until then, preload only the sounds that must be instant and let `OneShot` clean up after itself. The rest can wait.

---

## Working with the library

- **Set sounds up in Studio for their most common use.** Then use [presets](./Presets.md) or change properties in code for the small things that differ. If a sound ends up very different from its original, make it a separate sound in Studio, even with the same `SoundId`.
- **Keep sounds out of game logic.** Game code should not wait on a sound or branch on one. Play sounds from the code that already knows what happened.
- **Plan names for scale.** Names are the only way to fetch a sound, so they have to be unique across the whole game. A prefix per area, like `UI_Click` or `Boss_Roar`, keeps that manageable once you have hundreds of sounds.
