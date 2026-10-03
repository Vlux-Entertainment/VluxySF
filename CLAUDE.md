# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

**VluxySF** ("Vluxy Sound Factory") is Vlux Entertainment's open-source **Roblox sound-management
library**, published to Wally as `greenviper126/vluxysf` (MIT). It turns a Studio-authored folder of
Sound instances into a serialized, deep-frozen "schema" that both server and client consume, so game
code fetches sounds by name instead of holding instance references. TheLaundryShift (sibling repo)
is one consumer; the library also reportedly runs in a live Roblox game peaking above 20k CCU daily,
so treat the published API as production-facing — breaking changes and behavior changes need real
version bumps, and leak/perf fixes matter more than they look in Studio.

Two deliverables live here:

1. **`lib/`** — the Wally package itself (what ships; see `include`/`exclude` in `wally.toml`).
2. **Docs** — Moonwave/Docusaurus site (`moonwave.toml`, `docs/*.md`, generated `build/`).

The companion tooling lives in a separate repo, **Vlux-Entertainment/VluxySFExtension**: a VS Code
extension plus the Studio plugin it bundles and installs as a local plugin. The plugin sends the
game's sound names to the extension, which regenerates `lib/_vluxysf_sound_name_types.luau` so
`Fetch("...")` gets autocomplete/typed names. The plugin used to live here in `plugin/`.

Language: **Luau**, `--!strict`. Managed with **Rojo**; toolchain pinned in `aftman.toml`
(rojo, wally, selene, stylua).

## Commands

| Task | Command |
|---|---|
| Test place sync | Rojo-Hub (VS Code panel) with its project file set to `test-place.project.json` (lib + `Tests/` scripts in one place); an agent calls Rojo-Hub's `serve_here` from its worktree before checking in Studio. Without Rojo-Hub, `rojo serve test-place.project.json` |
| Package-only build | `rojo build default.project.json` |
| Preview what Wally would publish | `.\PackageTests\list.ps1` |
| Build + unpack the publish tarball | `.\PackageTests\refresh.ps1` (inspect result in `PackageTests/unpacked/`) |
| Publish | `wally publish` (bump `version` in `wally.toml` first) |
| Lint / format | `selene lib` / `stylua lib` |
| Docs preview | `moonwave dev` |

There is no automated test runner. `Tests/` contains manual scripts that run in the test place
(`ServerTests.server.luau`, `ClientTests.client.luau`, `SoundTest.client.luau`, `StudioTests.luau`).

## Architecture

### The schema pipeline

1. The game author builds a `Configuration` named **`SOUNDS`** in ServerStorage: Folders =
   organization, `UPPER_CASE` folder names = SoundGroups (created automatically), Sound instances =
   definitions, keyed by their Name (names must be unique — they are the global lookup keys).
2. Server calls `VluxySF.Startup.InitServer(soundsConfig)` once — `lib/Internals/Server.luau` walks
   the folder, serializes every Sound + its effects (`lib/Tools/Converters.luau`,
   `lib/Utility/Properties.luau`) into a **SoundSchema**, deep-freezes it, and exposes it to clients
   (via the `lib/Utility/RemoteFunction.luau` wrapper).
3. Client calls `VluxySF.Startup.InitClient(timeout?)` once — fetches the schema, preloads sounds
   tagged for preloading. Gate schema-dependent code with `Startup.WaitForSchema()` /
   `ConnectForSchema()` / `IsInitialized()`.

### Public API surface (`lib/init.luau`)

- **Fetching**: `Fetch(name, parent?, preset?)` (falls back to a blank sound on failure),
  `FetchStrict(...)` (returns nil instead), `FetchPlayOnce(...)` (one-shot, self-destroying,
  returns a cleanup function). Un-parented fetches land in `schema.UnattachedSounds`.
- **`Startup`** — init/wait (above). **`Schema`** — `Get/GetDefinitions/GetDefinition/GetNames`.
- **`Groups`** — SoundGroup access + `SetMainVolume`/`SetVolumes`.
- **`Preload`** (client-only) — permanent named clones; **`Cache`** (client-only) —
  `Warm`/`Chill`/`IsWarmed`, temporary keep-loaded cache. Both make `Fetch` clone instead of create.
- **`Conversions`** — Sound ⇄ SoundDefinition. **`Presets`** (`lib/Sections/SoundPresets.luau`) —
  reusable `(Sound) -> ()` mutators. **`Jitter`** (`lib/Sections/Jitter.luau`) — randomization
  helpers.
- `GeneratedSoundNames` (the string type of every sound name) comes from
  `lib/_vluxysf_sound_name_types.luau`, which the extension and its Studio plugin (VluxySFExtension
  repo) **overwrite per consumer game** — in this repo it stays the generic fallback; don't
  hand-edit it.

## Conventions

- `--!strict` everywhere; rich exported types in `lib/Types.luau` (schema, serialized effects).
- Moonwave doc comments on all public API (`@class` per API section: VluxySF, Startup, Schema,
  SoundGroups, Preload, Cache, Conversions), with `@tag RequiresSchema` / `@client` / `@server`
  markers. Keep tags accurate — they drive the docs site.
- User-facing warnings/errors go through `FormatMessage` (prefixes messages with the library name).
- Version bumps happen in `wally.toml` and are mentioned in the commit message
  ("Version 1.0.4! …"). No git tags currently.
- `README.md` doubles as the docs landing page (`moonwave-hide-before-this-line`).

## Gotchas

- **Schema is locked after init** (deep-frozen) — no sounds/groups can be registered at runtime.
- Most API errors at call time if used before init (`schemaFailCheck`), and `Preload`/`Cache` are
  client-only (`clientFailCheck`).
- `PackageTests/unpacked/` is a **committed snapshot of a previously built tarball** — it goes
  stale until someone reruns `refresh.ps1`; never treat it as source.
- `build/` is the generated docs site — never edit by hand.
- Two docs URLs exist historically (`Vlux-Entertainment.github.io/VluxySF` in README); keep new
  links consistent with the README.
