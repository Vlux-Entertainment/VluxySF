---
sidebar_position: 7
---


# Extension

The VluxySF library also comes with a companion `Extension`, which brings its own Roblox Studio `Plugin`. Using it is completly optional.

---

## Instructions
Install the [Extension](https://github.com/Vlux-Entertainment/VluxySFExtension) in VS-Code.

From version `0.5.0` the extension installs the `Plugin` for you as a local plugin and keeps it up to date; restart Roblox Studio when the extension says the plugin was installed.

On older versions of the extension, install the [Plugin](https://create.roblox.com/store/asset/135156375922001/Vluxy-Sound-Factory-Companion?viewFromStudio=true&keyword=&searchId=58eb3ad0-447b-4e8d-a720-bca87c689362) in Roblox yourself. Remove it in Studio's plugin manager once you update to `0.5.0` or newer, or two copies of the plugin will run.

Make sure your ports match in the extension and plugin; by default its `7842`.

Once done just click on the VluxySF icon in the plugins tab and you should hear a connect sound. If it stays connected then you should be ready to bake your types.

## How It Works
What this companion software will do is bake types for you. More specifically it will make a unioned string literal of all your sound names under the `SOUNDS Configuration`.

It is highly recommend that you use [Luau-LSP](https://github.com/JohnnyMorganz/luau-lsp) for your `Language Server Provider`.

*If you do end up using `Luau-LSP` then make sure `Enable Fragment AutoComplete` is off. At the moment`(2/28/2026)` it causes inline suggests to not auto popup most the time.*

---

Example of the extension in use:
![Extension Use Example](/VluxySFExtensionExample1.png)

> **Note:** This extension has a `limit of 800 sounds` for type baking!

---

Example of what the type will look like internally by default:
```lua
--!strict

export type BakedTypes = string

return nil
```

Example of what the type will look like internally once baked:
```lua
--!strict

export type BakedTypes = "A Cure for All" | "Agaiiiiiin" | "Bubble Pop Parade" | "Clara OL" | ...

return nil
```

Example of what the type will look like internally once baked if `LooseTypes` is on in the `Extension`:
```lua
--!strict

export type BakedTypes = string | "A Cure for All" | "Agaiiiiiin" | "Bubble Pop Parade" | "Clara OL" | ...

return nil
```