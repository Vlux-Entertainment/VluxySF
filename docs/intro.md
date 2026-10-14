---
sidebar_position: 1
---

# Introduction

## What is VluxySF?

**VluxySF** (Vluxy Sound Factory) is a sound library for Roblox that lets you play any sound in your game by its name.

You build your sounds in Studio the way you normally would, with their volume, effects and SoundGroup set up, and put them in one `Configuration`. The library turns that into a compact list both the server and the clients can read, and builds a fresh `Sound` whenever you ask for one:

```lua
VluxySF.OneShot("DoorCreak", door) -- Plays once from the door, then cleans itself up.

local music = VluxySF.Fetch("MainTheme", workspace)
music:Play()
```

## Why use it?

- **Fetch by name.** No folder walking and no `WaitForChild` chains. Move your sounds around in Studio as much as you like; your code does not change.
- **SoundGroups from your folder layout.** Every top-level group in your sounds Configuration becomes a `SoundGroup`, with a volume for each and one main volume, ready for a settings menu.
- **Low memory.** A `Sound` only exists while you use it. The rest of your library is a small compressed description: about 30 bytes per sound in a real game.
- **Fast.** Starting takes milliseconds even with 10,000 sounds, and fetching a sound costs about as much as creating one by hand.
- **Stays out of your way.** A misspelled name, a bad volume, audio that was deleted or a mistake in your sound setup prints a warning and carries on. The library never throws an error into your game code.
- **Ready when it matters.** Preload the sounds that must play instantly, and warm the ones that matter for one part of the game.

## Why not use it?

- **Names have to be unique across the whole game.** Sounds are fetched by name with no folder path, so two sounds cannot share a name. With thousands of sounds, naming takes some discipline.
- **Sounds are fixed once the server starts.** You cannot add new sounds or SoundGroups while the game is running. Everything a game can play has to be in your sounds Configuration when the server starts.
- **It manages sounds, not playback.** VluxySF gives you a `Sound`; fades, crossfades and music systems are up to you. [Wrapping Sounds](./Wrapping.md) shows how to plug in your own class for that.

## Getting started

Follow these pages in order and you will have sounds playing in a few minutes:

1. [Installation](./Installation.md): add the package with Wally.
2. [Folder Setup](./FolderSetup.md): build your `SOUNDS` Configuration in Studio.
3. [Starting the Library](./Setup.md): start it on the server and the client.
4. [Fetching Sounds](./Fetching.md): play your first sound.

After that, each page in the sidebar covers one feature, and the [Cookbook](./Cookbook.md) has complete examples for common jobs like a volume settings menu or footsteps.

:::info
Upgrading from 2.x? 3.0 renames several functions. The [migration guide](./Migration.md) lists every change.
:::

## Getting help

- The [API reference](/api/VluxySF) documents every function, with its parameters, return values and an example.
- For questions and bug reports, join the [Discord](https://discord.gg/Ebbp9UgBUD) or open an issue on [GitHub](https://github.com/Vlux-Entertainment/VluxySF).

:::note
These docs assume you know Luau and how Roblox replication works: what runs on the server, what runs on the client, and how a `ModuleScript` is shared between scripts.
:::
