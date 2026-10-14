---
sidebar_position: 14
---

# How It Works

You do not need this page to use the library, but it helps when you want to know what happens behind a fetch, what it costs, and why the library behaves the way it does when something goes wrong.

---

## From Studio to a schema

When the server calls `Startup.InitServer(SOUNDS)`, the library walks your `SOUNDS` Configuration once:

1. Each group Configuration becomes a `SoundGroup` in `SoundService`.
2. Each `Sound` becomes a **definition**: its name, its group, every property that differs from a new `Sound`, and its effects. Properties left at their defaults are not stored at all.
3. All definitions are written into one compact block of bytes, the **schema**. Property names, enum names and sound names are stored once and referred to by number, asset ids are stored as numbers, and most numbers take four bytes.
4. The schema is compressed with a fast compressor, made text-safe, and stored in one attribute on a `Configuration` named `VluxySF_Schema` in `SoundService`.

Your `SOUNDS` Configuration is then removed. The schema is locked from here on: sounds and SoundGroups cannot be added while the game runs.

---

## Getting it to clients

`SoundService` replicates to every player as they join, so the schema arrives with the rest of the game. The client does not request anything from the server, and the server does no work per player.

`Startup.InitClient` waits for the schema, decompresses it and reads its index of sound names. That takes a few milliseconds even with 10,000 sounds. It then clears its own copy of the attribute to save memory, and starts the [preloads](./Preloading.md).

---

## What a fetch does

A definition is only decoded the first time its sound is fetched, then kept. A fetch:

1. Looks up the name, decoding its definition the first time.
2. Builds a `Sound` with those properties and effects, or clones it if the sound is [warm](./Warming.md).
3. Runs your preset.
4. Parents it.

Most of the cost is Roblox creating a `Sound` with a real asset: tens of microseconds on the client. The library's own share is a few microseconds.

---

## When things go wrong

VluxySF is built to stay out of your game's way. The rule is that nothing the library does at runtime throws an error into your code.

| What went wrong | What happens |
|---|---|
| A sound name that does not exist | A warning; `Fetch` gives a silent blank sound, `TryFetch` gives `nil`, `OneShot` plays nothing |
| Using the library before it has started | A warning the first time; empty or blank results |
| A volume that is not a number from 0 to 10 | A warning; nothing changes |
| `Preload` or `Cache` used on the server | A warning the first time; nothing happens |
| Audio that never loads in a `OneShot` | The sound is destroyed after 10 seconds, with a warning |
| A `SOUNDS` child that is not a Configuration, or a group name used twice | That part is skipped with a warning; the rest works |
| A sound with a property or effect that cannot be stored | That part is skipped with a warning |
| `InitServer` or `InitClient` called twice or on the wrong side | A warning; the extra call is ignored |
| Something fails while starting | A warning; sounds stay off, and the script that called `Init` keeps running |

Every warning starts with `[VluxySF]`, so you can find them in the output while testing.

The only errors that can reach you come from your own code, such as a preset or [wrapper](./Wrapping.md) function that throws.
