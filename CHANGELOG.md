# Changelog

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
