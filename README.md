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
- **Low memory use.** Sounds are compiled into a compact schema and created only when you ask for them.
- **Preloading and warming.** Keep the sounds that matter ready to play without a delay.
- **Presets and jitter.** Reusable functions that set up a sound, with natural volume and pitch variation.

## Installation

Add VluxySF to your `wally.toml` and run `wally install`:

```toml
[dependencies]
VluxySF = "greenviper126/vluxysf@^2"
```

## Quick start

Put your sounds in a `Configuration` named `SOUNDS` inside `ServerStorage`, then start the library on both sides.

**Server:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitServer(ServerStorage.SOUNDS)
```

**Client:**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)

VluxySF.Startup.InitClient()

VluxySF.FetchPlayOnce("LoFiBeat1")
```

`InitClient` yields until the sounds tagged for preloading are ready, or 5 seconds pass.

The [docs](https://Vlux-Entertainment.github.io/VluxySF/) cover the folder setup, more examples, and the full API.

## License

VluxySF is available under the [MIT License](LICENSE).
