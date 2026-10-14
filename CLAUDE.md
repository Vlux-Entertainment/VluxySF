# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

**VluxySF** ("Vluxy Sound Factory") is Vlux Entertainment's open-source **Roblox sound-management
library**, published to Wally as `greenviper126/vluxysf` (MIT). It turns a Studio-authored folder of
Sound instances into a compact, frozen "schema" that both server and client consume, so game code
fetches sounds by name instead of holding instance references. TheLaundryShift (sibling repo) is one
consumer; the library also runs in a live Roblox games, so treat the published API as production-facing:
breaking changes and behavior changes need real version bumps, and leak/perf fixes matter more than they 
look in Studio. Target scale is up to ~10k sounds.

Two deliverables live here:

1. **`lib/`** — the Wally package itself (what ships; see `include`/`exclude` in `wally.toml`).
2. **Docs** — Moonwave/Docusaurus site (`moonwave.toml`, `docs/*.md`, generated `build/`).

Language: **Luau**, `--!strict`. Managed with **Rojo**; toolchain pinned in `aftman.toml`
(rojo, wally, selene, stylua). The former companion VS Code extension and its generated sound-name
type were removed in 2.0; sound names are plain strings.

## Commands

| Task | Command |
|---|---|
| Test place sync | Rojo-Hub (VS Code panel) with its project file set to `stress-place.project.json`, the default: lib, `Tests/` scripts, the sound fixture and the 10k stress fixture in one place, so every Play runs the tests and the benchmarks. `test-place.project.json` is the same without the stress groups, for a quick run (switching needs the project stopped first). An agent calls Rojo-Hub's `serve_here` from its worktree before checking in Studio. Without Rojo-Hub, `rojo serve stress-place.project.json` |
| Package-only build | `rojo build default.project.json` |
| Preview what Wally would publish | `wally package --list --output vluxysf.tar.gz` (prints the file list, writes nothing) |
| Publish | `wally publish` (bump `version` in `wally.toml` first) |
| Lint / format | `selene lib Tests` / `stylua lib Tests` |
| Type check | `rojo sourcemap test-place.project.json -o sourcemap.json`, then `luau-lsp analyze --sourcemap sourcemap.json --definitions <globalTypes.d.luau> lib Tests` |
| Docs preview | `moonwave dev` |

### Tests

There is no automated test runner; the tests run when you press Play in the test place and print
one summary line per side (`[VluxySF Tests] Server: ...` / `Client: ...`), with a warning per
failed case. `Tests/` mirrors where each file lands in the place:

- `ServerStorage/TEST_SOUNDS.model.json` — the sound fixture (two groups, tagged preloads, a sound
  with effects, a sound with an enum and a NumberRange property). It is named `TEST_SOUNDS`, not
  `SOUNDS`, so syncing never replaces a `SOUNDS` Configuration saved in someone's place file.
  Change the fixture and `SharedCases` together.
- `ReplicatedStorage/TestHarness.luau` — the tiny suite/expectation helper.
- `ReplicatedStorage/SharedCases.luau` — cases that must pass on both server and client.
- `ReplicatedStorage/InternalCases.luau` — cases that require `lib/Core` modules directly (codec round
  trips, property rules, compile errors); schema-free, run on both sides.
- `ServerScriptService/ServerTests.server.luau`, `StarterPlayerScripts/ClientTests.client.luau` —
  init the library, run the shared cases plus the side-specific ones (`Preload`/`Cache` on the client).
- `Stress/` + `stress-place.project.json` — the fixed stress fixture for comparable benchmarks: 9,999 sounds
  (8,000 unique public asset ids, 1,999 variants reusing ids with other properties, ~20% with an effect) in 11
  SoundGroups of 5000, 2500, ... 5, synced into `TEST_SOUNDS` by the default `stress-place.project.json`
  (`test-place.project.json` leaves them out). A full Play takes about a minute on the client. The files come from
  `Tests/Stress/generate.py` (seeded, byte-identical every run); regenerate only to change the fixture on purpose.
- `ServerScriptService/StressFixture.luau` — `Create(folders, sounds)` / `Remove()` from the command bar
  in edit mode; with 1000+ sounds compiled, both test scripts also run
  `ReplicatedStorage/Benchmarks.luau` (codec, build, fetch, clone, wrapper, OneShot and base64
  timings; numbers only, lines over a budget print as SLOW warnings) and print startup timings. Do not call anything that needs
  `WaitUntilReady` from the command bar: it has its own module cache in Studio and never initializes.
- `ServerScriptService/RealConfigCheck.server.luau` — runs only when a Configuration named `SOUNDS` is
  in ServerStorage next to `TEST_SOUNDS`; compiles it and compares every rebuilt sound and effect
  against the original without touching library state.

A few cases trigger library warnings on purpose (unknown sound names); those cases say so in their name.

## Architecture

### The schema pipeline

1. The game author builds a `Configuration` named **`SOUNDS`** in ServerStorage. Every direct
   child must be a `Configuration` and becomes a SoundGroup of the same name (anything else directly
   under `SOUNDS` throws). Folders and Configurations below that are organization only. Sound
   instances are definitions, keyed by Name (names must be unique; they are the global lookup keys).
   The tag `VluxySF_Preload` on a Sound or any container above it marks it for client preloading.
2. Server calls `VluxySF.Startup.InitServer(soundsConfig)` once. `lib/Core/Compile.luau` walks the
   tree once, converts every Sound and its effects (`lib/Core/Converters.luau`,
   `lib/Core/Properties.luau`) and writes them straight into one **schema buffer**
   (`lib/Core/Codec.luau`). `lib/Core/SchemaStore.luau` loads the buffer, creates the SoundGroups
   and holder Configurations in SoundService, and `lib/Core/Transport.luau` publishes the buffer
   as one base64 string attribute (`Schema`) on a `VluxySF_Schema` Configuration in SoundService, so it
   replicates with the place and is visible in Explorer; the client clears its copy after decoding. The
   Configuration is detached immediately and destroyed on the next frame.
3. Client calls `VluxySF.Startup.InitClient(timeout?)` once. It waits for the schema attribute to replicate,
   loads the buffer, builds the preload templates, and yields until they are loaded or the timeout
   passes. `0` means do not wait and do not warn. Gate schema-dependent code with
   `Startup.WaitUntilReady(timeout?)` / `OnReady()` / `IsReady()`; preload status is
   `IsPreloaded()` / `WaitUntilPreloaded(timeout?)`.

Definitions are decoded out of the buffer lazily, one per `GetDefinition`/`Fetch`, and cached
frozen. `Schema.Get()` and `Schema.GetDefinitions()` decode everything and freeze the table.

### Layout

- `lib/init.luau` assembles the public table and re-exports types. Nothing else.
- `lib/Api/` — one file per documented class: `Fetch` (`Fetch`, `TryFetch`, `OneShot`, `@within
  VluxySF`), `Startup`, `Schema`, `Groups`, `Preload`, `Cache`, `Conversions`, `Presets`, `Jitter`,
  `Wrapping` (`WithWrapper`, `@within VluxySF`: a frozen copy of the API whose fetches return a
  user wrapper class; the docs guide is `docs/Wrapping.md`).
- `lib/Core/` — the machinery with state: `SchemaStore` (single owner of schema state and the
  initialized/preloaded flags), `Codec`, `Compile`, `Transport`, `Templates` (preloaded and warmed
  template registries that `Fetch` clones from), `Preloading`, `Converters`, `Properties`.
- `lib/Utility/` — stateless helpers: `FormatMessage`, `Tables`.
- `lib/Types.luau` — exported types (schema, serialized effects).

### Hot paths

- `Properties.GetClassInfo` learns the storable properties of a class once (ReflectionService,
  probed on a fresh instance, deprecated aliases and runtime state denied) so reads are a plain
  loop with no per-property pcall. Keep new property exclusions in its deny list.
- `Properties.Apply` and `ReadChanged` try the whole table without pcall first and fall back to
  per-property pcall with a warning only when something fails.
- The codec interns names in a string table; string values stay inline. Counts, ids, lengths and the
  index's definition gaps are varints; numbers use f32 when that round-trips exactly; `rbxassetid://`
  ids are stored as varint numbers (only when formatting back gives the identical string); booleans
  live in the tag. The buffer has no magic or version header: only this library writes it, and server
  and client always run the same copy. `Transport` compresses it with `Core/Compression.luau`
  (LZ4-style block format) before base64.

## Conventions

- `--!strict` everywhere; rich exported types in `lib/Types.luau`.
- Moonwave doc comments on all public API (`@class` per API section), with `@tag RequiresSchema` /
  `@client` / `@server` markers. Keep tags accurate; they drive the docs site.
- User-facing warnings/errors go through `FormatMessage` (prefixes messages with the library name).
- Version bumps happen in `wally.toml` and are mentioned in the commit message
  ("Version 2.0.0! …"). No git tags currently.
- The docs home page is built from `moonwave.toml` (`[home]` features, `includeReadme = false`);
  `README.md` is for GitHub and the Wally package. Guide pages in `docs/` are ordered by
  `sidebar_position` and link to each other with relative `./Page.md` links; keep their code
  samples in line with the real API in `lib/Api/`. The guides follow the Cmdr / Promise docs
  style: one topic per page in learning order (Introduction, Why VluxySF?, Installation, Folder
  Setup, Starting, Fetching, Presets, SoundGroups, Preloading, Warming, Wrapping, How It Works,
  Performance, Cookbook, Migration), concepts and examples in the guides, exact signatures left
  to the API pages, and complete recipes in `Cookbook.md`. A new feature gets its own page or a
  section on the matching one, not a catch-all page. `moonwave build --out-dir ../somewhere`
  checks for broken links (delete the output after).
- Text files are LF (`.gitattributes`, `.editorconfig`, `stylua.toml`).

## Gotchas

- **Schema is locked after init.** No sounds or groups can be registered at runtime.
- **Never in the way:** nothing a game calls at runtime may throw. Every API function starts with
  `SchemaStore.CheckReady(name)` (and `CheckClient(name)` for `Preload`/`Cache`), which warn once
  per function and return false; the function then returns a blank sound, `nil` or an empty value.
  `Init*` warn on misuse and pcall their startup work. Keep new API functions to this rule; the
  only errors left are from the developer's own code (a `WithWrapper` wrap that errors, or
  `WithWrapper` given a non-function).
- `wally.toml`'s `exclude` list is what keeps repo-only files (tests, docs, tool configs,
  `CLAUDE.md`) out of the published package. A new top-level file ships unless it is added there.
- `build/` is the generated docs site. Never edit it by hand.
- Two docs URLs exist historically (`Vlux-Entertainment.github.io/VluxySF` in README); keep new
  links consistent with the README.
