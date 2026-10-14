---
sidebar_position: 8
---

# Migrating to 3.0

3.0 renames several functions and tightens a few parameters. Your `SOUNDS` Configuration, tags and sound names do not change. Most of the work is find and replace with the tables below.

First, change the version in your `wally.toml` to `@^3` and run `wally install`.

:::tip
3.0 never throws into your game code. If you miss a rename, the old name is simply missing from the library table, and Luau's type checker or the first call points you at it. Search your project for each old name below.
:::

---

## Fetching

| 2.x | 3.0 |
|---|---|
| `VluxySF.FetchStrict(name, parent, preset)` | `VluxySF.TryFetch(name, parent, preset)` |
| `VluxySF.FetchPlayOnce(name, parent, preset)` | `VluxySF.OneShot(name, parent, preset)` |
| `VluxySF.FetchPlayOnce(name, parent, preset, true)` | `VluxySF.OneShot(name, parent, preset)`, see below |
| `VluxySF.Fetch(name, parent, preset)` | unchanged |

`OneShot` has no `waitOnLoad` argument. Roblox already holds a played sound until its audio arrives and then plays it from the beginning, so the argument did nothing you can hear. Drop it.

**Behavior change:** before the library has started, `Fetch` returns an unparented blank `Sound`, `TryFetch` returns `nil` and `OneShot` plays nothing. In 2.x all three threw an error.

---

## Startup

| 2.x | 3.0 |
|---|---|
| `Startup.IsInitialized()` | `Startup.IsReady()` |
| `Startup.WaitForSchema()` | `Startup.WaitUntilReady(timeout?)` → `boolean` |
| `Startup.ConnectForSchema(callback)` | `Startup.OnReady(callback)` |
| `Startup.WaitForPreload()` | `Startup.WaitUntilPreloaded(timeout?)` → `boolean` |
| `Startup.IsPreloaded()` | unchanged |
| `Startup.InitServer(config)`, `Startup.InitClient(timeout?)` | unchanged |

Both waits take an optional timeout and return `false` if it passed first. Without a timeout they wait as long as needed, like before.

**Behavior changes:**

- Calling `InitServer` or `InitClient` twice, on the wrong side, or with a bad argument prints a warning instead of throwing.
- If starting fails, sounds turn off with a warning instead of the error breaking the script that called `Init`.
- On the server, `IsPreloaded` is `true` and `WaitUntilPreloaded` returns right away once `InitServer` has run. In 2.x, `WaitForPreload` on the server waited forever.

---

## Preload

| 2.x | 3.0 |
|---|---|
| `Preload.Selected(...)` | `Preload.AddAsync(...)` |
| `Preload.Get()` | `Preload.GetNames()` for the names, `Preload.Has(name)` for one sound |

`Get` used to hand out the kept `Sound` instances. They are internal now: they only exist to keep the audio loaded, and `Fetch` builds a new sound instead of cloning them.

A name that is already preloaded is skipped without a warning.

---

## Cache

| 2.x | 3.0 |
|---|---|
| `Cache.Get()` | `Cache.GetNames()` |
| `Cache.Warm(...)`, `Cache.Chill(...)`, `Cache.IsWarmed(name)` | unchanged |

On the server, `Preload` and `Cache` now warn once and do nothing. In 2.x they threw.

---

## Schema

| 2.x | 3.0 |
|---|---|
| `Schema.GetDefinition(name)` | unchanged, but no longer warns for an unknown name |
| (none) | `Schema.Has(name)` → `boolean` |
| `Schema.Get()` → `SoundSchema` | `Schema.Get()` → `SoundSchema?` |

`Schema.Get()` returns `nil` before the library has started. If your code only runs after startup, `assert(VluxySF.Schema.Get())` keeps the old type.

---

## Groups

| 2.x | 3.0 |
|---|---|
| `Groups.GetByName(name)` | `Groups.Get(name)` |
| `Groups.Get()` | `Groups.GetAll()` |
| `Groups.SetVolumes(main, volumes)` | `Groups.SetMainVolume(main)` and `Groups.SetVolumes(volumes)` |
| `Groups.SetVolumes(nil, volumes)` | `Groups.SetVolumes(volumes)` |
| `Groups.SetMainVolume(volume)`, `Groups.GetNames()` | unchanged |
| (none) | `Groups.SetVolume(name, volume)`, `Groups.GetMain()`, `Groups.GetVolumes()`, `Groups.GetMainVolume()` |

`Get` changed meaning: in 2.x `Groups.Get()` returned every group, in 3.0 `Groups.Get(name)` returns one. Search for `Groups.Get(` and check each call.

A volume has to be a number from 0 to 10; anything else prints a warning and is ignored. `GetNames` now lists the groups in the order they appear under `SOUNDS`.

---

## Jitter

| 2.x | 3.0 |
|---|---|
| `Jitter.Default(center, spread)` | `Jitter.Uniform(center, spread)` |
| `Jitter.UnitLog(center, spread)` | `Jitter.Natural(center, spread)` |
| `Jitter.Scale(spread)` | `Jitter.Uniform(1, spread)` |
| `Jitter.Range(min, max)` | unchanged |

Jitter values are now only kept from going below 0. They used to be clamped from 0 to 10.

`Presets` is unchanged.

---

## Types

| 2.x | 3.0 |
|---|---|
| `VluxySF.GeneratedSoundNames` | `string` |

---

## Docs pages

The `SoundGroups` and `SoundPresets` API pages are now [Groups](/api/Groups) and [Presets](/api/Presets), matching `VluxySF.Groups` and `VluxySF.Presets` in code.
