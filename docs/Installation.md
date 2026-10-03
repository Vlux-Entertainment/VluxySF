---
sidebar_position: 2
---

# Installation

VluxySF is installed with [Wally](https://wally.run/), a package manager for Roblox, and synced into Studio with [Rojo](https://rojo.space/).

## 1. Add the package

If your project does not use Wally yet, run `wally init` in your project directory first.

Then add VluxySF under `[dependencies]` in your `wally.toml`:

```toml
[package]
name = "your_name/your_project"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
VluxySF = "greenviper126/vluxysf@^1"
```

Run `wally install` in your project. Wally creates a `Packages` folder that contains VluxySF.

## 2. Sync the package into Studio

VluxySF runs on both the server and the client, so the `Packages` folder has to be somewhere both can reach. `ReplicatedStorage` is the usual place.

Add the `Packages` folder to your Rojo project file:

```json
{
	"name": "your_project",
	"tree": {
		"$className": "DataModel",
		"ReplicatedStorage": {
			"$className": "ReplicatedStorage",
			"Packages": {
				"$path": "Packages"
			}
		}
	}
}
```

## 3. Require it

With the setup above, you can require the library from any script:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VluxySF = require(ReplicatedStorage.Packages.VluxySF)
```

Every example in these docs uses this path. If your `Packages` folder is somewhere else, change the path to match.

## Next step

The library needs sounds to work with. Continue to [Folder Setup](./FolderSetup.md).
