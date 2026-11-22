# CLAUDE.md

Guidance for Claude Code when working in this repository. This file is the hub: `ARCHITECTURE.md`
(repo root, not published) holds the detail; `grep -n '^#' ARCHITECTURE.md` lists its sections.

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
(rojo, wally, selene, stylua). Sound names are plain strings.

## Rules

1. **Never in the way:** nothing a game calls at runtime may throw. Every API function starts with
   `SchemaStore.CheckReady(name)` and returns a blank sound, `nil` or an empty value on misuse. Read
   ARCHITECTURE.md "Gotchas" before adding an API function.
2. **The schema is locked after init.** No sounds or groups can be registered at runtime.
3. **`Owned.Mark` before parenting**, so the mark replicates with the instance.
4. **Version bumps** go in `wally.toml` and the commit message ("Version 2.0.0! …"). No git tags.
5. **Never hand-edit `build/`** (the generated docs site).
6. **PRs: open and merge your own.** This repo has no Greptile review, so an agent opens its PR and
   merges it once lint, format and the type check pass. Say in the PR when the tests were not run in
   Studio. Publishing to Wally still needs the user.

## Commands

| Task | Command |
|---|---|
| Test place sync | Rojo-Hub (VS Code panel) with its project file set to `stress-place.project.json`, the default: lib, `Tests/` scripts, the sound fixture and the 10k stress fixture in one place, so every Play runs the tests and the benchmarks. `test-place.project.json` is the same without the stress groups, for a quick run (switching needs the project stopped first). An agent calls Rojo-Hub's `serve_here` from its worktree before checking in Studio. Without Rojo-Hub, `rojo serve stress-place.project.json` |
| Package-only build | `rojo build default.project.json` |
| Preview what Wally would publish | `wally package --list --output vluxysf.tar.gz` (prints the file list, writes nothing) |
| Publish | `wally publish` (bump `version` in `wally.toml` first) |
| Lint / format | `selene lib Tests` / `stylua lib Tests` |
| Type check | `rojo sourcemap stress-place.project.json -o sourcemap.json`, then `luau-lsp analyze --sourcemap sourcemap.json --definitions <globalTypes.d.luau> lib Tests` |
| Doc comments | `moonwave-extractor extract lib` must print JSON, not an error |
| Docs preview | `moonwave dev` |

**Tests** have no automated runner: press Play in the test place; each side prints one
`[VluxySF Tests] Server: ...` / `Client: ...` line and a warning per failed case. The fixture, the
case files, the stress fixture and what Studio cannot test: ARCHITECTURE.md "Tests". Change
`TEST_SOUNDS` and `SharedCases` together.

## Layout

- `lib/init.luau` assembles the public table and re-exports types. Nothing else.
- `lib/Api/` — one file per documented class: `Fetch` (`Fetch`, `TryFetch`, `OneShot`, `@within
  VluxySF`), `Startup`, `Schema`, `Groups`, `Preload`, `Cache`, `Conversions`, `Presets`, `Jitter`,
  `Wrapping` (`WithWrapper`, `@within VluxySF`: a frozen copy of the API whose fetches return a
  user wrapper class; the docs guide is `docs/Wrapping.md`).
- `lib/Core/` — the machinery with state: `SchemaStore` (single owner of schema state and the
  initialized/preloaded flags), `Codec`, `Compile`, `Transport`, `Templates` (preloaded and warmed
  template registries that `Fetch` clones from), `Preloading`, `Converters`, `Properties`,
  `Compression`.
- `lib/Utility/` — stateless helpers: `FormatMessage`, `Tables`, `Signal`, `Owned` (marks the
  instances the library creates and finds them again by name, class and mark with a deadline).
- `lib/Types.luau` — exported types (schema, serialized effects).

How the schema gets from `SOUNDS` to the client: ARCHITECTURE.md "The schema pipeline". Codec and
property fast paths: "Hot paths".

## Conventions

- `--!strict` everywhere; rich exported types in `lib/Types.luau`.
- Moonwave doc comments on all public API (`@class` per API section), with `@tag RequiresSchema` /
  `@client` / `@server` markers. Keep tags accurate; they drive the docs site.
- User-facing warnings/errors go through `FormatMessage` (prefixes messages with the library name).
- Docs guides in `docs/`: one topic per page, code samples in line with `lib/Api/`. Full style:
  ARCHITECTURE.md "Docs site style".
- Text files are LF (`.gitattributes`, `.editorconfig`, `stylua.toml`).

## Facts that catch people

- The schema travels as base64 in `Schema` StringValues (`Schema#2`, ... past 199,999 characters), not
  a string attribute: Studio and Server Authority cap those at 50 characters.
- `Transport.Publish` runs before `SchemaStore.LoadServer` on purpose.
- Every client wait shares one 30-second deadline (`SCHEMA_TIMEOUT` in `Startup`).
- `Playing` and `TimePosition` are never read or stored; templates are silenced when stored.
- Do not call anything that needs `WaitUntilReady` from the command bar: it never initializes there.
- `wally.toml`'s `include` is a whitelist; `exclude` is the second guard for repo-only files.
- Two docs URLs exist historically (`Vlux-Entertainment.github.io/VluxySF` in README); keep new links
  consistent with the README.
