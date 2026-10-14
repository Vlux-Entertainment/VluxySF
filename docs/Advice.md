---
sidebar_position: 7
---

# Advice

Tips for using the library well and for keeping sound memory low.

---

## Why does this library exist?

**This library is designed for fast iteration!**

Finding a sound by walking folders takes several lines, and it errors when the sound moves or is removed. Fetching by name removes both problems.

### How far does it scale?

The schema is compiled on the server into a compact buffer and replicates to clients with the place, so a large sound library costs little at startup. Definitions are only decoded when they are asked for.

The practical limit is naming. There is no hierarchy when fetching sounds; it is completely flat. So the difficulty of giving every sound a unique name goes up as the number of sounds goes up.

---

## Working with the library

- **Set your sounds up in Studio for their most common use.** Adjust each sound in edit mode, then use [presets](./Examples.md#presets) or change properties yourself for the small things that differ at runtime. If a sound ends up too different from its original copy, it may be better to make a new `Sound`, even if it has the same `SoundId`.

- **Keep sounds out of game logic.** Game code should not wait on a sound or branch on one. Fetch and play sounds from the code that already knows what happened.

- **Gate code that runs before startup.** Most of the API errors if it is used before `Startup.InitServer` or `Startup.InitClient` has run. Scripts that may run earlier should call `VluxySF.Startup.WaitForSchema()` or `VluxySF.Startup.ConnectForSchema(callback)` first.

- **Start the client fast with `InitClient(0)`.** By default, `Startup.InitClient` yields until the tagged sounds preload or 5 seconds pass. If your game wants the fastest possible client start, pass `0`: the call returns right away, the preloads still run in the background, and no timeout warning is printed. Check on them later with `Startup.IsPreloaded()` or `Startup.WaitForPreload()`.

  ```lua
  VluxySF.Startup.InitClient(0)

  -- Other startup work runs while the preloads download.

  VluxySF.Startup.WaitForPreload()
  ```

---

## Memory optimizations

Optimizing may be important if your game needs to run on phones or old devices.

In short:

- Only preload the sounds that you know need it.
- Lazy load your sounds wherever possible.
- Destroy sounds when you don't need them for the moment.
- Use third party software like Audacity or FL Studio to compress your audio.

### Preloading

This library makes preloading easy, as you just need to tag a sound with `VluxySF_Preload`. But just because it's easy, that doesn't mean you should preload everything, especially if your game uses more than 20 sounds. The more sounds you preload, the more memory is taken up throughout the game.

:::warning
There is no way to undo preloading a sound.
:::

If a sound only has to be ready for a while, like the sounds of one map, [warm it](./Examples.md#warm-and-chill) instead. You can chill it again once you are done.

### Lazy loading

Lazy loading means creating a sound only when it is needed. Call `VluxySF.Fetch` at the moment you need the sound, not ahead of time, and destroy it when you are done.

### Destroying your sounds

If you want to save more memory, destroy the sound made by VluxySF once you're done playing it. `VluxySF.FetchPlayOnce` does this for you automatically.

:::note
Lazy loading and destroying only save memory if the `SoundId` was not preloaded and no other sound with the same `SoundId` exists.
:::

### Reading the schema

`VluxySF.Schema.Get()` and `VluxySF.Schema.GetDefinitions()` decode every definition in the schema and keep them in memory. If you only need one, use `VluxySF.Schema.GetDefinition(name)`, which decodes just that one.

### Sound editing

Editing your audio files should be a last resort, as it is the most tedious of these methods. There is also a monthly import limit for audio in Roblox. But this is the best way to save memory, if it's worth it to you.

---

## When to optimize?

Optimize sound memory when you have a reason to: a memory warning on a target device, or a polish pass before release. Until then, tag only the sounds that must be ready instantly and destroy sounds you are done with. The rest can wait.
