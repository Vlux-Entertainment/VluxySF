# Changelog

## 2.1.0

### Added

- `VluxySF.WithWrapper(wrap)` returns a copy of the library whose `Fetch` and `FetchStrict` return your own class instead of a `Sound`. It is fully typed, and `VluxySF` itself is unchanged. See the Wrapping Sounds guide.

### Changed

- The schema replicates as one string attribute named `Schema` on a `VluxySF_Schema` Configuration in `SoundService`, so it is visible in the Explorer. It used to be split across StringValues in a folder under the library module. The client clears its copy of the attribute after decoding it.
- `InitServer` errors if Roblox refuses or shortens the schema attribute, instead of leaving clients waiting.
- The schema buffer no longer starts with a magic byte and a format version. Server and client always run the same copy of the library, so the check could never fail.
- The schema is about half the size. Counts, ids and lengths are variable-length integers, `rbxassetid://` ids are stored as numbers, numbers that fit 32-bit floats take 4 bytes, booleans fit in their tag, and the index stores the gap between definitions. A 180-sound game config went from 15,765 to 8,037 bytes.
- The schema is compressed (LZ4-style, built for speed) before it is published. The same config shrinks to 5,459 bytes; compressing took 0.3 ms and decompressing 0.05 ms. At 10,000 realistic sounds decompressing takes about 3 to 4 ms.
- Names and string values have no length limit in the schema; the old format capped names at 65,535 bytes and a schema at 65,535 unique names.

### Fixed

- `FetchPlayOnce` destroys the sound, with a warning, when its asset has not loaded within 10 seconds. Deleted, moderated or private audio never loads and never fires `Ended`, so these sounds used to stay in `UnattachedSounds` forever.
- A failed `ContentProvider:PreloadAsync` only warns. Before, it could make `Preload.Selected` throw and leave `WaitForPreload` waiting forever.
- Enums decoded from one schema can no longer be mixed up with another schema's. The enum lookup cache is kept per loaded schema instead of shared.

### Removed

- The `GeneratedSoundNames` type, kept in 2.0 only for code that annotated sound names with it. Use `string`. This is a type-only change: running code is unaffected, but annotations that name the type no longer type-check.

## 2.0.0

The core was rewritten for speed and scale. The public API is the same shape as 1.x, with the changes below.

### Changed

- The schema is compiled on the server into one compact buffer and replicates to clients with the place. Clients no longer request it, and the server does no work per player.
- Definitions are decoded when they are first asked for. `Schema.Get()` and `Schema.GetDefinitions()` decode every definition and freeze the table. `Schema.GetDefinition(name)` decodes one.
- `Startup.InitClient(0)` starts the preloads in the background without waiting and prints no timeout warning.
- On the client, the schema is marked ready as soon as it is received. `WaitForSchema` and `ConnectForSchema` resume before the preloads finish; `InitClient` itself still waits for them.
- `Startup.InitServer` detaches the `SOUNDS` Configuration right away and destroys it shortly after instead of synchronously.
- `Startup.InitServer` and `Startup.InitClient` error when called a second time.
- Two SoundGroups with the same name make `InitServer` throw.
- A `VluxySF_Preload` tag on a group Configuration preloads the whole group.
- Presets run on an unparented `Sound`. A sound the preset leaves unparented lands in `UnattachedSounds`.
- `FetchPlayOnce` with a name that is not in the schema warns, plays nothing, and leaves nothing behind. Before, the blank sound it returned stayed in `UnattachedSounds` forever.
- `Preload.Get()` returns the templates that live in `SoundService.PreloadedSounds`. Preloaded sounds are built once, not twice.
- Deprecated `Sound` properties such as `Pitch`, `MaxDistance`, `MinDistance` and `EmitterSize` are no longer stored.
- Warning and error messages were reworded. A definition that fails to apply warns once per failing property instead of silently stopping.
- The library table is frozen.

### Added

- `Startup.IsPreloaded()` and `Startup.WaitForPreload()`.
- `Conversions.FromDefinition` accepts definitions without `EffectsCount` and skips effect entries that are not `SoundEffect` classes.

### Removed

- The companion VS Code extension and the generated sound-name type. `GeneratedSoundNames` is still exported and is now `string`.
- The `RemoteFunction` and `RateLimit` internals.

## 1.0.4

Last release of the 1.x line.
