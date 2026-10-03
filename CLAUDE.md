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
| Test place sync | Rojo-Hub (VS Code panel) with its project file set to `test-place.project.json` (lib + `Tests/` scripts and sound fixture in one place); an agent calls Rojo-Hub's `serve_here` from its worktree before checking in Studio. Without Rojo-Hub, `rojo serve test-place.project.json` |
| Package-only build | `rojo build default.project.json` |
| Preview what Wally would publish | `wally package --list --output vluxysf.tar.gz` (prints the file list, writes nothing) |
| Publish | `wally publish` (bump `version` in `wally.toml` first) |
| Lint / format | `selene lib Tests` / `stylua lib Tests` |
| Type check the tests | `rojo sourcemap test-place.project.json -o sourcemap.json`, then `luau-lsp analyze --sourcemap sourcemap.json --definitions <globalTypes.d.luau> Tests` |
| Docs preview | `moonwave dev` |

### Tests

There is no automated test runner; the tests run when you press Play in the test place and print
one summary line per side (`[VluxySF Tests] Server: ...` / `Client: ...`), with a warning per
failed case. `Tests/` mirrors where each file lands in the place:

- `ServerStorage/TEST_SOUNDS.model.json` — the sound fixture (two groups, tagged preloads, a sound
  with effects). It is named `TEST_SOUNDS`, not `SOUNDS`, so syncing never replaces a `SOUNDS`
  Configuration saved in someone's place file. Change the fixture and `SharedCases` together.
- `ReplicatedStorage/TestHarness.luau` — the tiny suite/expectation helper.
- `ReplicatedStorage/SharedCases.luau` — cases that must pass on both server and client.
- `ServerScriptService/ServerTests.server.luau`, `StarterPlayerScripts/ClientTests.client.luau` —
  init the library, run the shared cases plus the side-specific ones (`Preload`/`Cache` on the client).
- `ServerScriptService/StressFixture.luau`, `ReplicatedStorage/FetchBenchmark.luau` — run from the
  command bar for large-schema checks; their header comments have the commands.

A few cases trigger library warnings on purpose (unknown sound names); those cases say so in their name.

## Architecture

### The schema pipeline

1. The game author builds a `Configuration` named **`SOUNDS`** in ServerStorage. Every direct
   child must be a `Configuration` and becomes a SoundGroup of the same name (`UPPER_CASE` is only
   the naming convention; anything else directly under `SOUNDS` throws). Folders below that are
   organization only. Sound instances = definitions, keyed by their Name (names must be unique —
   they are the global lookup keys).
2. Server calls `VluxySF.Startup.InitServer(soundsConfig)` once — `lib/Internals/Server.luau` walks
   the folder, serializes every Sound + its effects (`lib/Tools/Converters.luau`,
   `lib/Utility/Properties.luau`) into a **SoundSchema**, deep-freezes it, and exposes it to clients
   (via the `lib/Utility/RemoteFunction.luau` wrapper). It then **destroys the Configuration it
   was given**.
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
- The docs home page is built from `moonwave.toml` (`[home]` features, `includeReadme = false`);
  `README.md` is for GitHub and the Wally package. Guide pages in `docs/` are ordered by
  `sidebar_position` and link to each other with relative `./Page.md` links; keep their code
  samples in line with the real API in `lib/init.luau`.
- Text files are LF (`.gitattributes`, `.editorconfig`, `stylua.toml`).

## Gotchas

- **Schema is locked after init** (deep-frozen) — no sounds/groups can be registered at runtime.
- Most API errors at call time if used before init (`schemaFailCheck`), and `Preload`/`Cache` are
  client-only (`clientFailCheck`).
- `wally.toml`'s `exclude` list is what keeps repo-only files (tests, docs, tool configs,
  `CLAUDE.md`) out of the published package — a new top-level file ships unless it is added there.
- `build/` is the generated docs site — never edit by hand.
- Two docs URLs exist historically (`Vlux-Entertainment.github.io/VluxySF` in README); keep new
  links consistent with the README.
