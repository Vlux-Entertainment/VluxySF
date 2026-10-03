<div align="center">
	<img src=".moonwave/static/VluxIcon.png" alt="Vlux Entertainment" height="150" />
	<br/>
	<a href="https://discord.gg/Ebbp9UgBUD"><img src="https://img.shields.io/discord/757104089984270346.svg?label=discord" /></a>
	<p><a href="https://Vlux-Entertainment.github.io/VluxySF/">View Docs</a></p>
</div>

<!--moonwave-hide-before-this-line-->

# VluxySF

**Vluxy Sound Factory** is a sound management library for Roblox with a focus on simplicity.
Build your sounds in Studio, then fetch any of them by name from the server or the client.

```lua
local sound = VluxySF.Fetch("LoFiBeat1")
sound:Play()
```

## Features

- **Fetch by name.** No folder searching, and no errors when a sound moves or goes missing.
- **Automatic SoundGroups.** Your folder layout becomes your SoundGroups, with a volume for each group and a main volume.
- **Low memory use.** Sounds are stored as lightweight definitions and created only when you ask for them.
- **Preloading and warming.** Keep the sounds that matter ready to play without a delay.
- **Presets and jitter.** Reusable functions that set up a sound, with natural volume and pitch variation.
- **Typed sound names.** An optional VS Code extension gives you autocomplete for your sound names.

## Installation

Add VluxySF to your `wally.toml` and run `wally install`:

```toml
[dependencies]
VluxySF = "greenviper126/vluxysf@^1"
```

## Quick start

Put your sounds in a `Configuration` named `SOUNDS` inside `ServerStorage`, then start the library on both sides.

**Server:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitServer(ServerStorage:FindFirstChild("SOUNDS"))
```

**Client:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitClient()

VluxySF.FetchPlayOnce("LoFiBeat1")
```

The [docs](https://Vlux-Entertainment.github.io/VluxySF/) cover the folder setup, more examples, and the full API.

## Companion extension

If you want type checking when fetching your sounds, you can use the companion VS Code extension.
On request, your sound names are sent from Roblox Studio and converted into a Luau type.

[Companion Extension](https://github.com/Vlux-Entertainment/VluxySFExtension)

The extension needs its Roblox Studio plugin to function:

- From version 0.5.0, the extension installs the plugin for you as a local plugin, so there is nothing else to download.
- On older versions, install the [Companion Plugin](https://create.roblox.com/store/asset/135156375922001/Vluxy-Sound-Factory-Companion?viewFromStudio=true&keyword=&searchId=58eb3ad0-447b-4e8d-a720-bca87c689362) from the Creator Store. Remove it again once you update to 0.5.0 or newer, or two copies of the plugin will run.

## License

VluxySF is available under the [MIT License](LICENSE).
