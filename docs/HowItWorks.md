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
4. The schema is compressed with a fast compressor, made text-safe, and stored in one attribute on a `Configuration` named `VluxySF_Schema` in `SoundService`. A `RemoteFunction` named `Request` sits under it as a fallback.

Your `SOUNDS` Configuration is then removed. The schema is locked from here on: sounds and SoundGroups cannot be added while the game runs.

Every instance the library creates in `SoundService` carries an attribute named `VluxySF`. That is how a client tells the library's `SOUNDS` SoundGroup or `UnattachedSounds` holder from an instance of your own that happens to have the same name, so you can keep those if you have them.

---

## Getting it to clients

`SoundService` replicates to every player as they join, so the schema normally arrives with the rest of the game. The client requests nothing from the server, and the server does no work per player.

If a client cannot read the attribute, because it is missing, cut short or damaged (`NextGenerationReplication` limits how long a script-set string attribute can be), it asks the server for the schema through the `Request` RemoteFunction instead. The server answers a few requests per player and ignores the rest, so a misbehaving client cannot make it resend the schema over and over.

`Startup.InitClient` waits for the schema, decompresses it and reads its index of sound names. That takes a few milliseconds even with 10,000 sounds. The attribute is left as it is, so other code on the client can still read it. `InitClient` then starts the [preloads](./Preloading.md).

The wait is bounded. If the schema and the library's instances have not arrived after 30 seconds, because the server could not start, `InitClient` prints a warning and returns with sounds off for that player, so the script that called it keeps running.

---

## What a fetch does

A definition is only decoded the first time its sound is fetched, then kept. A fetch:

1. Looks up the name, decoding its definition the first time.
2. Builds a `Sound` with those properties and effects, or clones it if the sound is [warm](./Warming.md).
3. Runs your preset.
4. Parents it.

Most of the cost is Roblox creating a `Sound` with a real asset: tens of microseconds on the client. The library's own share is a few microseconds.

A fetched sound is always stopped and at the start. `Playing` and `TimePosition` are playback state, not setup, so they are never compiled into the schema: a `Sound` in `SOUNDS` is never playing. The kept copies that [preloading](./Preloading.md) and [warming](./Warming.md) hold in `SoundService` are silent for the same reason, with `PlayOnRemove` turned off on them and restored on the sounds `Fetch` hands out.

---

## When things go wrong

VluxySF is built to stay out of your game's way. The rule is that nothing the library does at runtime throws an error into your code.

| What went wrong | What happens |
|---|---|
| A sound name that does not exist | A warning; `Fetch` gives a silent blank sound, `TryFetch` gives `nil`, `OneShot` plays nothing |
| Using the library before it has started | A warning the first time; empty or blank results. A blank sound from `Fetch` still goes to the parent you gave |
| A parent that is not an Instance, or a preset that is not a function | A warning; it is ignored, and the sound goes where an unparented one would |
| A parent that refuses the sound (locked or destroyed) | A warning; the sound goes to `UnattachedSounds` |
| A volume that is not a number from 0 to 10 | A warning; nothing changes |
| A preset or jitter builder given something that is not a number, a parent that is not an Instance, or `Range` bounds in the wrong order | A warning where the builder was called; the preset does nothing, the jitter gives a fixed value, or the bounds are swapped |
| `Conversions` given something that is not a `Sound` or not a definition | A warning; a blank definition or a blank `Sound` |
| `Preload` or `Cache` used on the server | A warning the first time; nothing happens |
| Audio that never loads in a `OneShot` | The sound is destroyed after 10 seconds, with a warning |
| A `OneShot` whose parent is destroyed while it plays | Nothing; the sound went with its parent |
| A `SOUNDS` child that is not a Configuration, or a group name used twice | That part is skipped with a warning; the rest works |
| A sound with a property or effect that cannot be stored | That part is skipped with a warning |
| Your own `SOUNDS` or `UnattachedSounds` already in `SoundService` | Nothing; the library finds its own instances by their `VluxySF` mark |
| The schema attribute cannot be read on a client | The client asks the server for the schema instead |
| `InitServer` or `InitClient` called twice or on the wrong side | A warning; the extra call is ignored |
| Something fails while starting | A warning; sounds stay off, and the script that called `Init` keeps running. A later `Init` call says the first one failed |
| The schema never arrives on a client | After 30 seconds, a warning; sounds stay off for that player, and the script keeps running |

Every warning starts with `[VluxySF]`, so you can find them in the output while testing.

The only errors that can reach you come from your own code, such as a preset or [wrapper](./Wrapping.md) function that throws. When a preset throws, the sound it was applied to is destroyed first.
