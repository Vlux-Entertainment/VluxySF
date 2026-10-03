---
sidebar_position: 1
---

# Getting Started

**VluxySF** (Vluxy Sound Factory) lets you fetch any sound in your game by its name.
You build your sounds in Roblox Studio like you normally would, and the library takes care of finding them, grouping them, and creating them when you ask.

```lua
local sound = VluxySF.Fetch("LoFiBeat1")
sound:Play()
```

No folder searching, no `WaitForChild` chains, and no errors when a sound moves or goes missing.

## How it works

1. You put your `Sounds` inside a `Configuration` named `SOUNDS` in `ServerStorage`.
2. When the server starts, VluxySF reads every `Sound` and turns it into a lightweight **definition**. All the definitions together are called the **schema**.
3. The schema is shared with every client, so both sides can create any sound on demand from its name.

Because only definitions are stored, a `Sound` instance exists only while you are using it. That keeps memory low, and you can still [preload](./FolderSetup.md#preloading-sounds) the few sounds that have to be ready instantly.

## Set it up

Follow these pages in order and you will have sounds playing in a few minutes:

1. [Installation](./Installation.md): add the package with Wally.
2. [Folder Setup](./FolderSetup.md): build your `SOUNDS` Configuration in Studio.
3. [Initialization](./Setup.md): start the library on the server and the client.
4. [Examples](./Examples.md): fetch, play, and adjust your sounds.

## Go further

- [Extension](./Extension.md): get autocomplete and type checking for your sound names in VS Code.
- [Advice](./Advice.md): tips on using the library well and keeping sound memory low.
- [**API Docs**](/api/VluxySF): every function, with examples.
