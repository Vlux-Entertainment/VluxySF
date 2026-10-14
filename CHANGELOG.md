# Changelog

## 3.0.0

3.0 renames several functions, makes the schema about a third of its old size, and changes how the library behaves when something goes wrong: nothing it does at runtime throws into your game code anymore. Code written for 2.x needs the renames below.

### Renamed

| 2.x | 3.0 |
|---|---|
| `VluxySF.FetchStrict(name, parent, preset)` | `VluxySF.TryFetch(name, parent, preset)` |
| `VluxySF.FetchPlayOnce(name, parent, preset, waitOnLoad)` | `VluxySF.OneShot(name, parent, preset)` |
| `Startup.IsInitialized()` | `Startup.IsReady()` |
| `Startup.WaitForSchema()` | `Startup.WaitUntilReady(timeout?)` |
| `Startup.ConnectForSchema(callback)` | `Startup.OnReady(callback)` |
| `Startup.WaitForPreload()` | `Startup.WaitUntilPreloaded(timeout?)` |
| `Preload.Selected(...)` | `Preload.AddAsync(...)` |
| `Preload.Get()` | `Preload.GetNames()`, `Preload.Has(name)` |
| `Cache.Get()` | `Cache.GetNames()` |
| `Groups.GetByName(name)` | `Groups.Get(name)` |
| `Groups.Get()` | `Groups.GetAll()` |
| `Groups.SetVolumes(main, volumes)` | `Groups.SetMainVolume(main)` and `Groups.SetVolumes(volumes)` |
| `Jitter.Default(center, spread)` | `Jitter.Uniform(center, spread)` |
| `Jitter.UnitLog(center, spread)` | `Jitter.Natural(center, spread)` |
| `Jitter.Scale(spread)` | `Jitter.Uniform(1, spread)` |

`Groups.Get` changed meaning: it used to return every group and now returns one by name, so check each call rather than replacing it blindly. The `SoundGroups` and `SoundPresets` API pages are now `Groups` and `Presets`.

### Added

- `VluxySF.WithWrapper(wrap)` returns a copy of the library whose `Fetch` and `TryFetch` return your own class instead of a `Sound`. It is fully typed, and `VluxySF` itself is unchanged.
- `Schema.Has(name)` checks whether a sound exists without a warning.
- `Groups.SetVolume(name, volume)`, `Groups.GetMain()`, `Groups.GetVolumes()` and `Groups.GetMainVolume()`.
- `Startup.WaitUntilReady` and `Startup.WaitUntilPreloaded` take an optional timeout and return `false` if it passed first.

### Changed

- Nothing the library does at runtime throws anymore:
  - Called before the library has started, every function warns once and returns a blank sound, `nil` or an empty result.
  - `Preload` and `Cache` warn once and do nothing on the server.
  - `InitServer` and `InitClient` warn when called twice, on the wrong side or with a bad argument, and a failure while starting turns sounds off with a warning instead of breaking the calling script.
  - A child of `SOUNDS` that is not a Configuration, or a second group with a name already used, is skipped with a warning.
  - A volume that is not a number from 0 to 10 prints a warning and is ignored.
- `OneShot` has no `waitOnLoad` argument. Roblox already holds a played sound until its audio loads and plays it from the beginning.
- `Schema.Get` returns `nil` before the library has started, and `Schema.GetDefinition` no longer warns for an unknown name.
- `Fetch` builds preloaded sounds instead of cloning their kept copies, which measured faster. It still clones warmed sounds.
- `Groups.GetNames` lists groups in the order they appear under `SOUNDS`.
- Jitter values are kept at 0 or more instead of being clamped from 0 to 10.
- The schema is about a third of its old size. Counts and lengths are variable-length integers, `rbxassetid://` ids are stored as numbers, numbers that fit 32-bit floats take 4 bytes, and the whole schema is compressed with a fast LZ4-style compressor. A real 180-sound game went from 15,765 bytes to 5,459; decompressing it takes 0.05 ms.
- The schema replicates as one string attribute named `Schema` on a `VluxySF_Schema` Configuration in `SoundService`, visible in the Explorer. It used to be split across StringValues under the library module. The client clears its copy after reading it.
- Names and other strings in the schema have no length limit, and there is no limit on the number of unique names.

### Fixed

- `OneShot` destroys a sound whose audio has not loaded within 10 seconds, with a warning. Deleted, moderated or private audio never fires `Ended`, so these sounds used to stay in `UnattachedSounds` forever.
- `Startup.WaitUntilPreloaded` returns right away on the server. `WaitForPreload` used to wait there forever.
- A failed audio preload only warns. It used to be able to throw from `Preload` and leave preload waits hanging.
- Enums read from one schema can no longer be mixed up with another schema's.

### Removed

- The `GeneratedSoundNames` type, kept in 2.0 only for code that annotated sound names with it. Use `string`.
- The magic byte and format version at the start of the schema. Server and client always run the same copy of the library, so the check could never fail.

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
